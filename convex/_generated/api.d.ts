/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as board from "../board.js";
import type * as boards from "../boards.js";
import type * as drops from "../drops.js";
import type * as files from "../files.js";
import type * as lib_enrich from "../lib/enrich.js";
import type * as lib_models from "../lib/models.js";
import type * as lib_rules from "../lib/rules.js";
import type * as lib_suggest from "../lib/suggest.js";
import type * as model from "../model.js";
import type * as moments from "../moments.js";
import type * as people from "../people.js";
import type * as pipeline from "../pipeline.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  board: typeof board;
  boards: typeof boards;
  drops: typeof drops;
  files: typeof files;
  "lib/enrich": typeof lib_enrich;
  "lib/models": typeof lib_models;
  "lib/rules": typeof lib_rules;
  "lib/suggest": typeof lib_suggest;
  model: typeof model;
  moments: typeof moments;
  people: typeof people;
  pipeline: typeof pipeline;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
