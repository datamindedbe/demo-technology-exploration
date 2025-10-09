{{ config(materialized='table') }}

with employee_summary as (
    select * from {{ ref('employee_summary') }}
),

salary_percentiles as (
    select 
        employee_id,
        current_salary,
        current_department_name,
        current_department_category,
        gender,
        years_of_service,
        tenure_category,
        
        -- Calculate percentiles within department
        round((percent_rank() over (
            order by current_salary
        ) * 100)::numeric, 1) as department_salary_percentile,
        
        -- Calculate percentiles within department category
        round((percent_rank() over (
            partition by current_department_category 
            order by current_salary
        ) * 100)::numeric, 1) as category_salary_percentile,
        
        -- Calculate percentiles within gender
        round((percent_rank() over (
            partition by gender 
            order by current_salary
        ) * 100)::numeric, 1) as gender_salary_percentile,
        
        -- Calculate percentiles within tenure category
        round((percent_rank() over (
            partition by tenure_category 
            order by current_salary
        ) * 100)::numeric, 1) as tenure_salary_percentile,
        
        -- Overall salary percentile
        round((percent_rank() over (order by current_salary) * 100)::numeric, 1) as overall_salary_percentile
        
    from employee_summary
    where current_salary is not null
),

salary_bands as (
    select 
        *,
        case 
            when overall_salary_percentile >= 90 then 'Top 10%'
            when overall_salary_percentile >= 75 then 'Top 25%'
            when overall_salary_percentile >= 50 then 'Top 50%'
            when overall_salary_percentile >= 25 then 'Bottom 50%'
            else 'Bottom 25%'
        end as salary_band,
        
        case 
            when current_salary < 50000 then 'Under $50k'
            when current_salary < 75000 then '$50k-$75k'
            when current_salary < 100000 then '$75k-$100k'
            when current_salary < 125000 then '$100k-$125k'
            when current_salary < 150000 then '$125k-$150k'
            else 'Over $150k'
        end as salary_range
        
    from salary_percentiles
)

select 
    employee_id,
    current_salary,
    current_department_name,
    current_department_category,
    gender,
    years_of_service,
    tenure_category,
    
    -- Percentile rankings
    department_salary_percentile,
    category_salary_percentile,
    gender_salary_percentile,
    tenure_salary_percentile,
    overall_salary_percentile,
    
    -- Salary bands and ranges
    salary_band,
    salary_range,
    
    -- Performance indicators
    case 
        when department_salary_percentile >= 75 and overall_salary_percentile >= 75 then 'High Performer'
        when department_salary_percentile >= 50 and overall_salary_percentile >= 50 then 'Average Performer'
        else 'Below Average'
    end as performance_indicator

from salary_bands
order by current_salary desc
