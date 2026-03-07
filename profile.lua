#!/usr/bin/env lua

-- Profile script for standard-clojure-style format() and parse()
-- Usage: lua profile_scs.lua [input_file.clj]

-- Load the profiler
dofile("libs/pepperfish.lua")

-- Load standard-clojure-style
local scs = dofile("standard-clojure-style.lua")

-- Sample Clojure code to use if no input file is provided
local sample_input = [=[
(ns my-app.core
  (:require [clojure.string :as str]
            [clojure.set :as set]))

(defn hello-world
  "A simple greeting function."
  [name]
  (println (str "Hello, " name "!")))

(defn process-items [items]
  (let [filtered (filter some? items)
        mapped (map #(update % :count inc) filtered)
        sorted (sort-by :name mapped)]
    (reduce (fn [acc item]
              (assoc acc (:name item) (:count item)))
            {}
            sorted)))

(defn -main [& args]
  (hello-world "World")
  (process-items [{:name "a" :count 1}
                  {:name "b" :count 2}
                  {:name "c" :count 3}]))
]=]

-- Read input from a file if provided, otherwise use sample
local input = sample_input
if arg[1] then
  local f = io.open(arg[1], "r")
  if f then
    input = f:read("*a")
    f:close()
    print("Read input from: " .. arg[1])
  else
    print("Could not open " .. arg[1] .. ", using sample input.")
  end
else
  print("No input file provided, using sample Clojure code.")
end

-- Number of iterations to get meaningful profiling data
local iterations = 10

------------------------------------------------------------------------
-- Profile parse()
------------------------------------------------------------------------
-- print("\n=== Profiling parse() ===")
-- print("Running " .. iterations .. " iterations...\n")

-- local parse_profiler = newProfiler("time")
-- parse_profiler:start()

-- local parsed
-- for i = 1, iterations do
--   parsed = scs.parse(input)
--   print(i)
-- end

-- parse_profiler:stop()

-- local parse_out = io.open("profile_parse.txt", "w+")
-- parse_profiler:report(parse_out)
-- parse_out:close()
-- print("parse() profile written to profile_parse.txt")

------------------------------------------------------------------------
-- Profile format()
------------------------------------------------------------------------
print("\n=== Profiling format() ===")
print("Running " .. iterations .. " iterations...\n")

local format_profiler = newProfiler("time")
format_profiler:start()

local formatted
for i = 1, iterations do
  formatted = scs.format(input)
  print(i)
end

format_profiler:stop()

local format_out = io.open("profile_format.txt", "w+")
format_profiler:report(format_out)
format_out:close()
print("format() profile written to profile_format.txt")

------------------------------------------------------------------------
-- Summary
------------------------------------------------------------------------
print("\n=== Done ===")
print("Results saved to:")
print("  profile_parse.txt   - parse() profiling data")
print("  profile_format.txt  - format() profiling data")
print("")
print("Tip: To profile with your own code, run:")
print("  lua profile_scs.lua path/to/your_file.clj")
