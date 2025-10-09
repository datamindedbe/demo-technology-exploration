{{ config(materialized='view') }}

with source_data as (
    select * from {{ source('employee_db', 'title') }}
),

renamed as (
    select
        employee_id,
        title as job_title,
        from_date as title_start_date,
        to_date as title_end_date,
        -- Flag for current title
        case 
            when to_date = '9999-01-01' then true 
            else false 
        end as is_current_title,
        -- Extract title level for analysis
        case 
            when title ilike '%senior%' then 'Senior'
            when title ilike '%staff%' then 'Staff'
            when title ilike '%engineer%' then 'Engineer'
            when title ilike '%manager%' then 'Manager'
            when title ilike '%assistant%' then 'Assistant'
            else 'Other'
        end as title_level,
        -- Calculate title duration in days
        case 
            when to_date = '9999-01-01' then 
                current_date - from_date
            else 
                to_date - from_date
        end as title_duration_days
    from source_data
)

select * from renamed
