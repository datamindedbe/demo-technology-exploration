{{ config(materialized='view') }}

with source_data as (
    select * from {{ source('employee_db', 'department') }}
),

renamed as (
    select
        id as department_id,
        dept_name as department_name,
        -- Create department categories for analysis
        case 
            when dept_name in ('Development', 'Research') then 'Technical'
            when dept_name in ('Sales', 'Marketing') then 'Commercial'
            when dept_name in ('Finance', 'Human Resources') then 'Support'
            when dept_name in ('Production', 'Quality Management') then 'Operations'
            else 'Other'
        end as department_category
    from source_data
)

select * from renamed
