{{ config(materialized='table') }}

with employee_summary as (
    select * from {{ ref('employee_summary') }}
),

department_stats as (
    select 
        current_department_name,
        current_department_category,
        count(*) as total_employees,
        count(distinct case when gender = 'M' then employee_id end) as male_employees,
        count(distinct case when gender = 'F' then employee_id end) as female_employees,
        
        -- Salary statistics
        round(avg(current_salary), 2) as avg_salary,
        round(min(current_salary), 2) as min_salary,
        round(max(current_salary), 2) as max_salary,
        round(percentile_cont(0.5) within group (order by current_salary)::numeric, 2) as median_salary,
        
        -- Tenure statistics
        round(avg(years_of_service)::numeric, 1) as avg_years_of_service,
        round(min(years_of_service)::numeric, 1) as min_years_of_service,
        round(max(years_of_service)::numeric, 1) as max_years_of_service,
        
        -- Title level distribution
        count(distinct case when current_title_level = 'Senior' then employee_id end) as senior_employees,
        count(distinct case when current_title_level = 'Staff' then employee_id end) as staff_employees,
        count(distinct case when current_title_level = 'Engineer' then employee_id end) as engineer_employees,
        count(distinct case when current_title_level = 'Manager' then employee_id end) as manager_employees,
        
        -- Tenure distribution
        count(distinct case when tenure_category = 'New (0-2 years)' then employee_id end) as new_employees,
        count(distinct case when tenure_category = 'Junior (2-5 years)' then employee_id end) as junior_employees,
        count(distinct case when tenure_category = 'Mid-level (5-10 years)' then employee_id end) as midlevel_employees,
        count(distinct case when tenure_category = 'Senior (10-20 years)' then employee_id end) as senior_tenure_employees,
        count(distinct case when tenure_category = 'Veteran (20+ years)' then employee_id end) as veteran_employees
        
    from employee_summary
    where current_department_name is not null
    group by current_department_name, current_department_category
)

select 
    current_department_name as department_name,
    current_department_category as department_category,
    total_employees,
    
    -- Gender distribution
    male_employees,
    female_employees,
    round(((male_employees::float / total_employees) * 100)::numeric, 1) as male_percentage,
    round(((female_employees::float / total_employees) * 100)::numeric, 1) as female_percentage,
    
    -- Salary metrics
    avg_salary,
    min_salary,
    max_salary,
    median_salary,
    round((max_salary - min_salary), 2) as salary_range,
    
    -- Tenure metrics
    avg_years_of_service,
    min_years_of_service,
    max_years_of_service,
    
    -- Title level distribution
    senior_employees,
    staff_employees,
    engineer_employees,
    manager_employees,
    
    -- Tenure distribution
    new_employees,
    junior_employees,
    midlevel_employees,
    senior_tenure_employees,
    veteran_employees,
    
    -- Calculated metrics
    round(((senior_employees::float / total_employees) * 100)::numeric, 1) as senior_percentage,
    round(((manager_employees::float / total_employees) * 100)::numeric, 1) as manager_percentage,
    round(((veteran_employees::float / total_employees) * 100)::numeric, 1) as veteran_percentage

from department_stats
order by total_employees desc
