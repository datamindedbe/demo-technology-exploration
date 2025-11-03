{{ config(materialized='view') }}

with employees as (
    select * from {{ ref('stg_employees') }}
),

current_salaries as (
    select * from {{ ref('stg_salaries') }}
    where is_current_salary = true
),

current_departments as (
    select * from {{ ref('stg_employee_departments') }}
    where is_current_assignment = true
),

current_titles as (
    select * from {{ ref('stg_titles') }}
    where is_current_title = true
),

departments as (
    select * from {{ ref('stg_departments') }}
)

select 
    e.employee_id,
    e.full_name,
    e.first_name,
    e.last_name,
    e.birth_date,
    e.gender,
    e.hire_date,
    e.age_at_hire,
    e.years_of_service,
    
    -- Current salary information
    cs.salary_amount as current_salary,
    cs.salary_start_date as current_salary_start_date,
    
    -- Current department information
    cd.department_id as current_department_id,
    d.department_name as current_department_name,
    d.department_category as current_department_category,
    cd.assignment_start_date as current_department_start_date,
    
    -- Current title information
    ct.job_title as current_job_title,
    ct.title_level as current_title_level,
    ct.title_start_date as current_title_start_date

from employees e
left join current_salaries cs on e.employee_id = cs.employee_id
left join current_departments cd on e.employee_id = cd.employee_id
left join departments d on cd.department_id = d.department_id
left join current_titles ct on e.employee_id = ct.employee_id
