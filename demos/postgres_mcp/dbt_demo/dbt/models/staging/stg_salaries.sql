{{ config(materialized='view') }}

with source_data as (
    select * from {{ source('employee_db', 'salary') }}
),

renamed as (
    select
        employee_id,
        amount as salary_amount,
        from_date as salary_start_date,
        to_date as salary_end_date,
        -- Flag for current salary
        case 
            when to_date = '9999-01-01' then true 
            else false 
        end as is_current_salary,
        -- Calculate salary duration in days
        case 
            when to_date = '9999-01-01' then 
                current_date - from_date
            else 
                to_date - from_date
        end as salary_duration_days
    from source_data
)

select * from renamed
