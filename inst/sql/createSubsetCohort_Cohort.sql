-- Subset Cohort - Temporal Filtering Based on Second Cohort
-- Creates a subset of a base cohort by filtering with temporal logic against another cohort
-- Example: Patients with CKD who had a T2D diagnosis in the prior year
--
-- Parameters:
--   base_cohort_id: The cohort definition ID to subset (e.g., CKD)
--   filter_cohort_id: The cohort definition ID to use for temporal filtering (e.g., T2D)
--   temporal_operator: 'during', 'before', 'after', 'overlapping'
--   temporal_start_offset: Start of window relative to base cohort event (negative = before, 0 = on date)
--   temporal_end_offset: End of window relative to base cohort event (negative = before, 0 = on date)
--   output_cohort_id: The new cohort definition ID for the subset
--   output_table: Schema.table to insert results into
--   base_cohort_table: Schema.table containing the base cohort

{DEFAULT @temporal_operator = 'during'}
{DEFAULT @temporal_start_offset = 0}
{DEFAULT @temporal_end_offset = 0}

INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  bc.subject_id,
  bc.cohort_start_date,
  bc.cohort_end_date
FROM @base_cohort_table bc
INNER JOIN @base_cohort_table fc
  ON bc.subject_id = fc.subject_id
  AND fc.cohort_definition_id = @filter_cohort_id
  {@temporal_operator == 'during'}?{
    -- Filter cohort event must occur during window relative to base cohort event
    AND fc.cohort_start_date >= DATEADD(DAY, @temporal_start_offset, bc.cohort_start_date)
    AND fc.cohort_start_date <= DATEADD(DAY, @temporal_end_offset, bc.cohort_end_date)
  }:{@temporal_operator == 'before'}?{
    -- Filter cohort event must occur before base cohort start date
    AND fc.cohort_end_date >= DATEADD(DAY, @temporal_start_offset, bc.cohort_start_date)
    AND fc.cohort_end_date < bc.cohort_start_date
  }:{@temporal_operator == 'after'}?{
    -- Filter cohort event must occur after base cohort end date
    AND fc.cohort_start_date >= bc.cohort_end_date
    AND fc.cohort_start_date <= DATEADD(DAY, @temporal_end_offset, bc.cohort_end_date)
  }:{@temporal_operator == 'overlapping'}?{
    -- Filter cohort event must overlap with base cohort
    AND fc.cohort_start_date <= bc.cohort_end_date
    AND fc.cohort_end_date >= bc.cohort_start_date
  }:{}
WHERE bc.cohort_definition_id = @base_cohort_id
;
