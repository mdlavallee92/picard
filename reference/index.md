# Package index

## Core Classes

Main R6 classes for package functionality

- [`CohortDef`](https://ohdsi.github.io/picard/reference/CohortDef.md) :
  CohortDef R6 Class
- [`CohortManifest`](https://ohdsi.github.io/picard/reference/CohortManifest.md)
  : CohortManifest R6 Class
- [`ConceptSetDef`](https://ohdsi.github.io/picard/reference/ConceptSetDef.md)
  : ConceptSetDef R6 Class
- [`ConceptSetManifest`](https://ohdsi.github.io/picard/reference/ConceptSetManifest.md)
  : ConceptSetManifest R6 Class
- [`ContributorLine`](https://ohdsi.github.io/picard/reference/ContributorLine.md)
  : ContributorLine R6 Class
- [`DbConfigBlock`](https://ohdsi.github.io/picard/reference/DbConfigBlock.md)
  : DbConfigBlock R6 Class
- [`ExecOptions`](https://ohdsi.github.io/picard/reference/ExecOptions.md)
  : ExecOptions R6 Class
- [`ExecutionSettings`](https://ohdsi.github.io/picard/reference/ExecutionSettings.md)
  : ExecutionSettings
- [`StudyMeta`](https://ohdsi.github.io/picard/reference/StudyMeta.md) :
  StudyMeta R6 Class
- [`UlyssesStudy`](https://ohdsi.github.io/picard/reference/UlyssesStudy.md)
  : UlyssesStudy R6 Class

## Creation Functions

Functions for creating objects and structures (make\*)

- [`makeExecOptions()`](https://ohdsi.github.io/picard/reference/makeExecOptions.md)
  : Make ExecOptions for Ulysses
- [`makeStudyMeta()`](https://ohdsi.github.io/picard/reference/makeStudyMeta.md)
  : Make Study Meta for Ulysses
- [`makeTaskFile()`](https://ohdsi.github.io/picard/reference/makeTaskFile.md)
  : Function initializing an R file for an analysis task
- [`makeUlyssesStudySettings()`](https://ohdsi.github.io/picard/reference/makeUlyssesStudySettings.md)
  : Make Ulysses Study Settings

## Initialization Functions

Functions for initializing components (init\*)

- [`initializeRenv()`](https://ohdsi.github.io/picard/reference/initializeRenv.md)
  : Initialize Renv for Project

## Build Functions

Functions for building study components (build\*)

- [`buildComplementCohort()`](https://ohdsi.github.io/picard/reference/buildComplementCohort.md)
  : Build a Complement Cohort Definition
- [`buildStudyHub()`](https://ohdsi.github.io/picard/reference/buildStudyHub.md)
  : Build Study Hub
- [`buildSubsetCohortDemographic()`](https://ohdsi.github.io/picard/reference/buildSubsetCohortDemographic.md)
  : Build a Subset Cohort Definition (Demographic)
- [`buildSubsetCohortTemporal()`](https://ohdsi.github.io/picard/reference/buildSubsetCohortTemporal.md)
  : Build a Subset Cohort Definition (Temporal)
- [`buildUnionCohort()`](https://ohdsi.github.io/picard/reference/buildUnionCohort.md)
  : Build a Union Cohort Definition

## Create Functions

Functions for creating new objects (create\*)

- [`createAgentBranch()`](https://ohdsi.github.io/picard/reference/createAgentBranch.md)
  : Create Feature Branch for Agent Work
- [`createBlankCohortsLoadFile()`](https://ohdsi.github.io/picard/reference/createBlankCohortsLoadFile.md)
  : Create Blank Cohorts Load File
- [`createBlankConceptSetsLoadFile()`](https://ohdsi.github.io/picard/reference/createBlankConceptSetsLoadFile.md)
  : Create Blank Concept Sets Load File
- [`createExecutionSettings()`](https://ohdsi.github.io/picard/reference/createExecutionSettings.md)
  : Create an ExecutionSettings object and set its attributes
- [`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/picard/reference/createExecutionSettingsFromConfig.md)
  : Create ExecutionSettings from Config Block
- [`createPullRequest()`](https://ohdsi.github.io/picard/reference/createPullRequest.md)
  : Create Pull Request Metadata

## Execution Functions

Functions for executing study tasks (exec\*)

- [`execStudyPipeline()`](https://ohdsi.github.io/picard/reference/execStudyPipeline.md)
  : Function to execute all study task in analysis folder on set of
  configBlock
- [`execStudyTask()`](https://ohdsi.github.io/picard/reference/execStudyTask.md)
  : Function to execute a study task in Ulysses

## Configuration Functions

Functions for configuration and setup (set\*)

- [`getTaskRunSummary()`](https://ohdsi.github.io/picard/reference/getTaskRunSummary.md)
  : Get Task Run Summary
- [`setAtlasConnection()`](https://ohdsi.github.io/picard/reference/setAtlasConnection.md)
  : Set Atlas Connection
- [`setContributor()`](https://ohdsi.github.io/picard/reference/setContributor.md)
  : Set Ulysses Contributor
- [`setDbConfigBlock()`](https://ohdsi.github.io/picard/reference/setDbConfigBlock.md)
  : set the config block for a database
- [`setOutputFolder()`](https://ohdsi.github.io/picard/reference/setOutputFolder.md)
  : Set Output Folder for Task

## Loading Functions

Functions for loading and importing data (load\*)

- [`loadCohortManifest()`](https://ohdsi.github.io/picard/reference/loadCohortManifest.md)
  : Load Cohort Manifest from Database or Cohort Files
- [`loadConceptSetManifest()`](https://ohdsi.github.io/picard/reference/loadConceptSetManifest.md)
  : Load Concept Set Manifest

## Utility Functions

Other utility and helper functions

- [`agentSaveWork()`](https://ohdsi.github.io/picard/reference/agentSaveWork.md)
  : Save Work for Agents (Automated, No Prompts)
- [`cleanColumnNames()`](https://ohdsi.github.io/picard/reference/cleanColumnNames.md)
  : Clean Column Names to Standard Format
- [`displayTaskStatusReport()`](https://ohdsi.github.io/picard/reference/displayTaskStatusReport.md)
  : Display Task Status Report
- [`documentDependencies()`](https://ohdsi.github.io/picard/reference/documentDependencies.md)
  : Document Dependencies
- [`formatFloats()`](https://ohdsi.github.io/picard/reference/formatFloats.md)
  : Format Float Columns
- [`formatPercentages()`](https://ohdsi.github.io/picard/reference/formatPercentages.md)
  : Format Percentage Columns
- [`generateCohorts()`](https://ohdsi.github.io/picard/reference/generateCohorts.md)
  : Generate Cohorts for Pipeline Execution
- [`importAndBind()`](https://ohdsi.github.io/picard/reference/importAndBind.md)
  : Import and Bind Results by Version and Task
- [`importAtlasCohorts()`](https://ohdsi.github.io/picard/reference/importAtlasCohorts.md)
  : Import CIRCE Cohort Definitions from ATLAS
- [`importAtlasConceptSets()`](https://ohdsi.github.io/picard/reference/importAtlasConceptSets.md)
  : Import CIRCE Concept Sets from ATLAS
- [`launchCohortsLoadEditor()`](https://ohdsi.github.io/picard/reference/launchCohortsLoadEditor.md)
  : Launch Interactive Cohort Load File Editor
- [`launchConceptSetsLoadEditor()`](https://ohdsi.github.io/picard/reference/launchConceptSetsLoadEditor.md)
  : Launch Interactive Concept Set Load Editor
- [`orchestratePipelineExport()`](https://ohdsi.github.io/picard/reference/orchestratePipelineExport.md)
  : Orchestrate Pipeline Export with Merging and QC
- [`pivotForComparison()`](https://ohdsi.github.io/picard/reference/pivotForComparison.md)
  : Pivot Data Wide for Comparison
- [`placeHolderExecOptions()`](https://ohdsi.github.io/picard/reference/placeHolderExecOptions.md)
  : set the execOptions as placeholder.
- [`prepareDisseminationData()`](https://ohdsi.github.io/picard/reference/prepareDisseminationData.md)
  : Prepare Dissemination Data with Chained Transformations
- [`recordTaskExecution()`](https://ohdsi.github.io/picard/reference/recordTaskExecution.md)
  : Record Task Execution Status
- [`resetCohortManifest()`](https://ohdsi.github.io/picard/reference/resetCohortManifest.md)
  : Reset Cohort Manifest Database
- [`resetConceptSetManifest()`](https://ohdsi.github.io/picard/reference/resetConceptSetManifest.md)
  : Reset Concept Set Manifest Database
- [`restoreEnvironment()`](https://ohdsi.github.io/picard/reference/restoreEnvironment.md)
  : Restore Environment from Lockfile
- [`reviewExportSchema()`](https://ohdsi.github.io/picard/reference/reviewExportSchema.md)
  : Review Export File Schema
- [`saveWork()`](https://ohdsi.github.io/picard/reference/saveWork.md) :
  Sync Local Work to Remote Branch
- [`shouldRerunTask()`](https://ohdsi.github.io/picard/reference/shouldRerunTask.md)
  : Check if Task Needs to be Rerun
- [`snapshotEnvironment()`](https://ohdsi.github.io/picard/reference/snapshotEnvironment.md)
  : Snapshot Current Environment State
- [`standardizeDataTypes()`](https://ohdsi.github.io/picard/reference/standardizeDataTypes.md)
  : Standardize Data Types
- [`templateAtlasCredentials()`](https://ohdsi.github.io/picard/reference/templateAtlasCredentials.md)
  : Template for setting Atlas Credentials
- [`updateStudyVersion()`](https://ohdsi.github.io/picard/reference/updateStudyVersion.md)
  : Function to update the study version
- [`validateCohortResults()`](https://ohdsi.github.io/picard/reference/validateCohortResults.md)
  : Validate Cohort Results Completeness
- [`validateConfigYaml()`](https://ohdsi.github.io/picard/reference/validateConfigYaml.md)
  : Validate config.yml File Structure
- [`validateStudyTask()`](https://ohdsi.github.io/picard/reference/validateStudyTask.md)
  : Validate Study Task Script
- [`validateUlyssesStructure()`](https://ohdsi.github.io/picard/reference/validateUlyssesStructure.md)
  : Validate Ulysses Repository Structure
- [`visualizeCohortDependencies()`](https://ohdsi.github.io/picard/reference/visualizeCohortDependencies.md)
  : Visualize Cohort Dependencies in a Report
- [`zipAndArchive()`](https://ohdsi.github.io/picard/reference/zipAndArchive.md)
  : Zip and Archive results from a study execution
