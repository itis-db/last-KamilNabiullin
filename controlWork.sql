-- 1
WITH total_sales_all AS (
    SELECT SUM(amount) AS total FROM order_items
),
     category_order_sales AS (
         SELECT
             p.category,
             oi.order_id,
             SUM(oi.amount) AS category_order_amount
         FROM
             order_items oi
                 JOIN
             products p ON oi.product_id = p.id
         GROUP BY
             p.category, oi.order_id
     )
SELECT
    cos.category,
    SUM(cos.category_order_amount) AS total_sales,
    AVG(cos.category_order_amount) AS avg_per_order,
    (SUM(cos.category_order_amount) / tsa.total) * 100 AS category_share
FROM
    category_order_sales cos,
    total_sales_all tsa
GROUP BY
    cos.category, tsa.total;


-- 2
WITH order_totals AS (
    SELECT
        o.customer_id,
        o.id AS order_id,
        o.order_date,
        SUM(oi.amount) AS order_total
    FROM
        orders o
            JOIN
        order_items oi ON o.id = oi.order_id
    GROUP BY
        o.customer_id, o.id, o.order_date
),
     customer_stats AS (
         SELECT
             customer_id,
             SUM(order_total) AS total_spent,
             AVG(order_total) AS avg_order_amount
         FROM
             order_totals
         GROUP BY
             customer_id
     )
SELECT
    ot.customer_id,
    ot.order_id,
    ot.order_date,
    ot.order_total,
    cs.total_spent,
    cs.avg_order_amount,
    (ot.order_total - cs.avg_order_amount) AS difference_from_avg
FROM
    order_totals ot
        JOIN
    customer_stats cs ON ot.customer_id = cs.customer_id
ORDER BY
    ot.customer_id, ot.order_id;


-- 3
WITH monthly_sales AS (
    SELECT
        TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
        SUM(oi.amount) AS total_sales
    FROM
        orders o
            JOIN
        order_items oi ON o.id = oi.order_id
    GROUP BY
        TO_CHAR(o.order_date, 'YYYY-MM')
),
     sales_with_prev AS (
         SELECT
             ms.year_month,
             ms.total_sales,
             (SELECT SUM(oi.amount)
              FROM orders o2
                       JOIN order_items oi ON o2.id = oi.order_id
              WHERE TO_CHAR(o2.order_date, 'YYYY-MM') =
                    TO_CHAR(TO_DATE(ms.year_month, 'YYYY-MM') - INTERVAL '1 year', 'YYYY-MM')
             ) AS prev_year_sales
         FROM
             monthly_sales ms
     )
SELECT
    sp.year_month,
    sp.total_sales,
    ROUND(
            CASE
                WHEN LAG(sp.total_sales, 1) OVER (ORDER BY sp.year_month) IS NOT NULL THEN
                (sp.total_sales - LAG(sp.total_sales, 1) OVER (ORDER BY sp.year_month)) /
                LAG(sp.total_sales, 1) OVER (ORDER BY sp.year_month) * 100
                END, 2
    ) AS prev_month_diff,
    ROUND(
            CASE
                WHEN sp.prev_year_sales IS NOT NULL THEN
                    (sp.total_sales - sp.prev_year_sales) / sp.prev_year_sales * 100
                END, 2
    ) AS prev_year_diff
FROM
    sales_with_prev sp
ORDER BY
    sp.year_month;