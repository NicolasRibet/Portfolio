SELECT c.country_name, r.region_name
FROM Countries c
INNER JOIN Region r ON c.region_id = r.region_id;

-- Count of employees by department with department name.
SELECT d.department_name, COUNT(e.employee_id)
FROM employees e
WHERE lcase(d.department_name) LIKE '%sales%'
RIGHT JOIN departments d ON e.department_id = d.department_id
GROUP BY department_name HAVING COUNT(e.employee_id) > 50;
