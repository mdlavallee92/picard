-- Union Cohort Template
-- Combines multiple cohorts with optional rule for overlap handling
-- Parameters:
--   @cohort_ids: Comma-separated list of cohort definition IDs to union
--   @cohort_ids_count: Number of cohort IDs in @cohort_ids (required for 'all' rule)
--   @union_rule: 'any' (all subjects from any cohort), 'all' (only subjects in ALL cohorts), 'at_least_n' (at least N cohorts)
--   @at_least_n: Number of cohorts required if using 'at_least_n' rule (default = 2)
--   @output_cohort_id: The new cohort definition ID for the union
--   @output_table: Schema.table to insert results into
--   @base_cohort_table: Schema.table containing the base cohorts

{DEFAULT @union_rule = 'any'}
{DEFAULT @at_least_n = 2}
{DEFAULT @cohort_ids_count = 0}

{@union_rule == 'any'}?{
  -- ANY rule: Include all subjects that appear in any of the specified cohorts
  INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
  SELECT
    @output_cohort_id AS cohort_definition_id,
    subject_id,
    MIN(cohort_start_date) AS cohort_start_date,
    MAX(cohort_end_date) AS cohort_end_date
  FROM @base_cohort_table
  WHERE cohort_definition_id IN (@cohort_ids)
  GROUP BY subject_id;
}:{
  {@union_rule == 'all'}?{
    -- ALL rule: Include only subjects that appear in ALL specified cohorts
    -- First, count how many cohorts each subject appears in
    INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
    WITH cohort_unions AS (
      SELECT
        subject_id,
        MIN(cohort_start_date) AS cohort_start_date,
        MAX(cohort_end_date) AS cohort_end_date,
        COUNT(DISTINCT cohort_definition_id) AS cohort_count
      FROM @base_cohort_table
      WHERE cohort_definition_id IN (@cohort_ids)
      GROUP BY subject_id
    )
    SELECT
      @output_cohort_id AS cohort_definition_id,
      subject_id,
      cohort_start_date,
      cohort_end_date
    FROM cohort_unions
    WHERE cohort_count = {@cohort_ids_count};
  }:{
    {@union_rule == 'at_least_n'}?{
      -- AT_LEAST_N rule: Include subjects that appear in at least N of the specified cohorts
      INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
      WITH cohort_counts AS (
        SELECT
          subject_id,
          MIN(cohort_start_date) AS cohort_start_date,
          MAX(cohort_end_date) AS cohort_end_date,
          COUNT(DISTINCT cohort_definition_id) AS cohort_count
        FROM @base_cohort_table
        WHERE cohort_definition_id IN (@cohort_ids)
        GROUP BY subject_id
      )
      SELECT
        @output_cohort_id AS cohort_definition_id,
        subject_id,
        cohort_start_date,
        cohort_end_date
      FROM cohort_counts
      WHERE cohort_count >= @at_least_n;
    }:{}
  }
}
