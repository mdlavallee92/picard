# Function to execute all study task in analysis folder on set of configBlock

Function to execute all study task in analysis folder on set of
configBlock

## Usage

``` r
execStudyPipeline(configBlock, updateType, env = rlang::caller_env())
```

## Arguments

- configBlock:

  name of one or multiple configBlock to use in the execution

- updateType:

  the type of version increment: 'major', 'minor', or 'patch'. The
  current version will be read from config.yml and incremented
  accordingly before pipeline execution.

- env:

  the execution environment
