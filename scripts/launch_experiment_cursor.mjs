#!/usr/bin/env node

import { Agent, CursorAgentError } from "@cursor/sdk";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { normalizeCursorApiKey, normalizeCursorModelId } from "./cursor_auth_util.mjs";

const __filename = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(__filename);
const experimentDir = path.dirname(scriptDir);

const config = {
  totalAgents: intFromEnv("N_TOTAL", 250),
  nPerCondition: intFromEnv("N_PER_CONDITION", 0),
  startIndex: intFromEnv("START_INDEX", 1),
  concurrency: intFromEnv("CONCURRENCY", 10),
  launchDelayMs: intFromEnv("LAUNCH_DELAY_MS", 5000),
  apiKey: normalizeCursorApiKey(process.env.CURSOR_API_KEY),
  model: normalizeCursorModelId(process.env.CURSOR_MODEL, "composer-2"),
  workRoot: process.env.WORK_ROOT || os.tmpdir(),
};

const requiredFiles = [
  "data/agent_panel_essential.csv",
  "DATA_DICTIONARY.md",
  "DID_METHODOLOGY.md",
  "INSTRUCTIONS_SHARED.md",
  "conditions.tsv",
];

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

async function main() {
  if (!config.apiKey) {
    throw new Error(
      "CURSOR_API_KEY is missing or empty after normalization. " +
        "Export your key with ASCII-only quotes, e.g. export CURSOR_API_KEY='crsr_...'"
    );
  }

  await validateRequiredFiles();
  const conditions = await readConditions();
  const nPerCondition = config.nPerCondition || Math.floor(config.totalAgents / conditions.length);
  const remainder = config.totalAgents - nPerCondition * conditions.length;

  if (remainder !== 0 && !config.nPerCondition) {
    throw new Error(
      `N_TOTAL=${config.totalAgents} is not divisible by ${conditions.length} conditions. ` +
        "Set N_PER_CONDITION explicitly."
    );
  }

  const startIndex = config.startIndex;
  const tasks = [];
  for (const condition of conditions) {
    for (let i = startIndex; i < startIndex + nPerCondition; i++) {
      tasks.push({ condition, index: i, agentId: `${condition.condition}_${String(i).padStart(3, "0")}` });
    }
  }

  console.log("============================================");
  console.log("Minimum Wage Many-Analyst Experiment");
  console.log("Cursor SDK local runner");
  console.log("============================================");
  console.log(`Conditions:  ${conditions.map((c) => c.condition).join(", ")}`);
  console.log(`Per condition: ${nPerCondition}`);
  console.log(`Total runs:    ${tasks.length}`);
  console.log(`Model:         ${config.model}`);
  console.log(`Concurrency:   ${config.concurrency}`);
  console.log(`Launch delay:  ${config.launchDelayMs} ms`);
  console.log("============================================");
  console.log("");

  const results = await runWithConcurrency(tasks, config.concurrency);
  const succeeded = results.filter((result) => result.status === "finished").length;
  const failed = results.length - succeeded;

  console.log("");
  console.log("============================================");
  console.log("All Cursor agents complete.");
  console.log(`Successful:        ${succeeded}`);
  console.log(`Failed/incomplete: ${failed}`);
  console.log("============================================");

  if (failed > 0) {
    process.exitCode = 2;
  }
}

async function validateRequiredFiles() {
  for (const relativePath of requiredFiles) {
    const absolutePath = path.join(experimentDir, relativePath);
    try {
      await fs.access(absolutePath);
    } catch {
      throw new Error(`Required file not found: ${absolutePath}`);
    }
  }
}

async function readConditions() {
  const conditionsPath = path.join(experimentDir, "conditions.tsv");
  const raw = await fs.readFile(conditionsPath, "utf8");
  const lines = raw.split(/\r?\n/).filter((line) => line.trim() && !line.startsWith("#"));
  const [headerLine, ...rows] = lines;
  const headers = headerLine.split("\t");
  const conditionIndex = headers.indexOf("condition");
  const labelIndex = headers.indexOf("label");
  const contextIndex = headers.indexOf("context_file");

  if (conditionIndex === -1 || labelIndex === -1 || contextIndex === -1) {
    throw new Error("conditions.tsv must have condition, label, and context_file columns.");
  }

  const conditions = rows.map((line) => {
    const cells = line.split("\t");
    return {
      condition: cells[conditionIndex].trim(),
      label: cells[labelIndex].trim(),
      contextFile: (cells[contextIndex] || "").trim(),
    };
  });

  for (const condition of conditions) {
    if (!/^[a-z0-9_-]+$/i.test(condition.condition)) {
      throw new Error(`Invalid condition name "${condition.condition}". Use letters, numbers, underscores, or dashes.`);
    }

    if (condition.contextFile) {
      await fs.access(path.join(experimentDir, condition.contextFile));
    }
  }

  return conditions;
}

async function runWithConcurrency(tasks, concurrency) {
  const results = [];
  let nextIndex = 0;
  let active = 0;
  let launched = 0;
  let lastLaunch = Promise.resolve();

  return await new Promise((resolve) => {
    const maybeStartNext = () => {
      if (nextIndex >= tasks.length && active === 0) {
        resolve(results);
        return;
      }

      while (active < concurrency && nextIndex < tasks.length) {
        const task = tasks[nextIndex++];
        active++;

        const start = lastLaunch.then(async () => {
          if (launched > 0) {
            await delay(config.launchDelayMs);
          }
          launched++;
        });
        lastLaunch = start;

        start
          .then(() => runAgent(task))
          .then((result) => results.push(result))
          .catch((error) => {
            console.error(`ERROR ${task.agentId}: ${error.message}`);
            results.push({ agentId: task.agentId, status: "error" });
          })
          .finally(() => {
            active--;
            maybeStartNext();
          });
      }
    };

    maybeStartNext();
  });
}

async function runAgent(task) {
  const workDir = path.join(config.workRoot, `mw_agent_${task.agentId}`);
  console.log(`Launching agent ${task.agentId} in ${workDir}`);

  await prepareWorkspace(workDir, task.condition);

  const prompt = buildPrompt(task.agentId, workDir, Boolean(task.condition.contextFile));
  await fs.writeFile(path.join(workDir, "prompt.txt"), prompt);

  const logPath = path.join(workDir, "agent_log.txt");
  await fs.writeFile(logPath, `agent_id: ${task.agentId}\ncondition: ${task.condition.condition}\nmodel: ${config.model}\n\n`);

  let agent;
  try {
    agent = await Agent.create({
      apiKey: config.apiKey,
      model: { id: config.model },
      local: { cwd: workDir, settingSources: [] },
    });

    const run = await agent.send(prompt);
    await appendLog(logPath, `agentId: ${agent.agentId}\nrunId: ${run.id}\n\n`);

    if (run.supports("stream")) {
      for await (const event of run.stream()) {
        await appendLog(logPath, formatEvent(event));
      }
    }

    const result = await run.wait();
    await appendLog(logPath, `\nfinal_status: ${result.status}\n`);

    if (result.status !== "finished") {
      console.error(`Agent ${task.agentId} ended with status ${result.status}`);
    }

    return { agentId: task.agentId, status: result.status };
  } catch (error) {
    if (error instanceof CursorAgentError) {
      await appendLog(logPath, `startup_error: ${error.message}\nretryable: ${error.isRetryable}\n`);
      console.error(`Startup failed for ${task.agentId}: ${error.message}`);
      return { agentId: task.agentId, status: "startup_error" };
    }

    await appendLog(logPath, `error: ${error.stack || error.message}\n`);
    throw error;
  } finally {
    if (agent) {
      if (typeof agent[Symbol.asyncDispose] === "function") {
        await agent[Symbol.asyncDispose]();
      } else if (typeof agent.close === "function") {
        agent.close();
      }
    }
  }
}

async function prepareWorkspace(workDir, condition) {
  await fs.rm(workDir, { recursive: true, force: true });
  await fs.mkdir(workDir, { recursive: true });

  await copyFromExperiment("data/agent_panel_essential.csv", path.join(workDir, "agent_panel_essential.csv"));
  await copyFromExperiment("DATA_DICTIONARY.md", path.join(workDir, "DATA_DICTIONARY.md"));
  await copyFromExperiment("DID_METHODOLOGY.md", path.join(workDir, "DID_METHODOLOGY.md"));
  await copyFromExperiment("INSTRUCTIONS_SHARED.md", path.join(workDir, "INSTRUCTIONS_SHARED.md"));

  if (condition.contextFile) {
    await copyFromExperiment(condition.contextFile, path.join(workDir, "LITERATURE_CONTEXT.md"));
  }
}

async function copyFromExperiment(relativePath, destination) {
  await fs.copyFile(path.join(experimentDir, relativePath), destination);
}

function buildPrompt(agentId, workDir, hasLiteratureContext) {
  const files = [
    "1. INSTRUCTIONS_SHARED.md - your task and deliverables",
    "2. DATA_DICTIONARY.md - variable descriptions",
    "3. DID_METHODOLOGY.md - methodology reference",
  ];

  if (hasLiteratureContext) {
    files.push("4. LITERATURE_CONTEXT.md - relevant empirical literature");
  }

  return `You are Agent ${agentId}. Your working directory is ${workDir}.

Read the following files in your working directory in this order:
${files.join("\n")}

Then conduct your analysis and produce:
- results.csv (one row with your estimates)
- llms.txt (structured summary)

Your agent_id for results.csv is: ${agentId}

Write all output files to: ${workDir}`;
}

function formatEvent(event) {
  if (event.type === "assistant" && event.message?.content) {
    return event.message.content
      .filter((block) => block.type === "text")
      .map((block) => block.text)
      .join("");
  }

  if (event.type === "error") {
    return `\n[event:error] ${event.message || JSON.stringify(event)}\n`;
  }

  return "";
}

async function appendLog(logPath, text) {
  if (text) {
    await fs.appendFile(logPath, text);
  }
}

function intFromEnv(name, defaultValue) {
  const value = process.env[name];
  if (!value) return defaultValue;

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative integer.`);
  }
  return parsed;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
