import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, extname, join } from "node:path";

const dir = process.argv[2] ?? "ios/Seed/SeedImages.xcassets";
const run = (fn, fnArgs = {}) => JSON.parse(execFileSync("npx", ["convex", "run", fn, JSON.stringify(fnArgs)], { encoding: "utf8" }));
const types = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png" };

if (!existsSync(dir)) console.warn(`no images at ${dir}, so both boards go in without photos`);
const images = {};
for (const set of existsSync(dir) ? readdirSync(dir).filter((d) => d.endsWith(".imageset")) : []) {
  for (const file of readdirSync(join(dir, set)).filter((f) => types[extname(f).toLowerCase()])) {
    const response = await fetch(run("files:generateUploadUrl"), {
      method: "POST",
      headers: { "Content-Type": types[extname(file).toLowerCase()] },
      body: readFileSync(join(dir, set, file)),
    });
    if (!response.ok) throw new Error(`uploading ${file} failed with ${response.status}`);
    images[basename(file, extname(file))] = (await response.json()).storageId;
  }
}
console.log(JSON.stringify(run("seed:run", { images }), null, 2));
