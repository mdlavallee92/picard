/* {fileName}.sql */

/* 
============================================================================
   META INFORMATION
============================================================================ 

   Study: {studyName}
   Author: {author}
   Date: {lubridate::today()}
   Description: {description}
============================================================================ 

============================================================================
   SQLRENDER PARAMETERS
============================================================================

   IMPORTANT: Document the parameters used in this query below
   Parameters are referenced using @ notation (e.g., @cdmDatabaseSchema)
   These will be substituted when the query is rendered in R
   
   Common parameters:
   @cdmDatabaseSchema - Schema containing OMOP CDM tables
   @workDatabaseSchema - Work schema for temporary/output tables
   @cohortTable - Table containing cohort definitions
============================================================================ 

============================================================================
   USAGE EXAMPLE (how to call this from R)
============================================================================
   
   sql <- readr::read_file(here::here("analysis/src/sql/query_name.sql"))
   rendered_sql <- SqlRender::render(sql, 
     cdmDatabaseSchema = "omop_cdm",
     workDatabaseSchema = "work_schema"
   )
   result <- DatabaseConnector::executeSql(connection, rendered_sql)
============================================================================ 
*/

/* QUERY */

SELECT *
FROM @cdmDatabaseSchema.condition_occurrence
LIMIT 100;

/* 
============================================================================
   TIPS FOR SQL IN SRC/SQL
============================================================================
   
   * Well-organized with clear section headers (see above)
   * Parameterized using SqlRender syntax (@paramName)
   * Documented with comments explaining what parameters are needed
   * Ready to be sourced and rendered from R task files
============================================================================ 
*/
