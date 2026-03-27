-- Complement Cohort Template
-- Creates a complement cohort: all people in population cohort MINUS people in exclude cohorts
-- Parameters:
--   population_cohort_id: The cohort definition ID representing the population
--   exclude_cohort_ids: Comma-separated list of cohort definition IDs to exclude
--   exclude_cohort_ids_count: Number of cohort IDs in @exclude_cohort_ids (required for 'exclude_all' rule)
--   complement_type: 'exclude_any' (exclude if in ANY exclude cohort), 'exclude_all' (exclude only if in ALL exclude cohorts)
--   output_cohort_id: The new cohort definition ID for the complement
--   output_table: Schema.table to insert results into
--   base_cohort_table: Schema.table containing the input cohorts

{DEFAULT @complement_type = 'exclude_any'}
{DEFAULT @exclude_cohort_ids_count = 0}

{@complement_type == 'exclude_any'}?{
  -- EXCLUDE_ANY rule: Remove subjects that appear in ANY of the exclude cohorts
  INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
  SELECT
    @output_cohort_id AS cohort_definition_id,
    pc.subject_id,
    pc.cohort_start_date,
    pc.cohort_end_date
  FROM @base_cohort_table pc
  WHERE pc.cohort_definition_id = @population_cohort_id
  AND NOT EXISTS (
    SELECT 1
    FROM @base_cohort_table ec
    WHERE ec.cohort_definition_id IN (@exclude_cohort_ids)
    AND ec.subject_id = pc.subject_id
  );
}:{
  {@complement_type == 'exclude_all'}?{
    -- EXCLUDE_ALL rule: Remove subjects only if they appear in ALL of the exclude cohorts
    INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
    WITH exclude_counts AS (
      SELECT
        subject_id,
        COUNT(DISTINCT cohort_definition_id) AS exclude_count
      FROM @base_cohort_table
      WHERE cohort_definition_id IN (@exclude_cohort_ids)
      GROUP BY subject_id
    )
    SELECT
      @output_cohort_id AS cohort_definition_id,
      pc.subject_id,
      pc.cohort_start_date,
      pc.cohort_end_date
    FROM @base_cohort_table pc
    WHERE pc.cohort_definition_id = @population_cohort_id
    AND NOT EXISTS (
      SELECT 1
      FROM exclude_counts ec
      WHERE ec.subject_id = pc.subject_id
      AND ec.exclude_count = {@exclude_cohort_ids_count}
    );
  }:{}
}
