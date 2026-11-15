import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval("suggest for clusters that changed", { hours: 1 }, internal.suggestions.hourly, {});

export default crons;
