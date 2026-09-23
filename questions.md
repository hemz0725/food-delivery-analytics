# Food Delivery — SQL Business Analysis Question Bank

50 questions across Revenue, Operations, Customer Behavior, Delivery Performance, and Retention.  
Progress from Easy → Medium → Hard. No SQL solutions. No hints on which functions to use.

---

## 🟢 EASY (Q1–Q12)

**Q1 · Revenue**
What is the total revenue generated across all orders in the dataset?

---

**Q2 · Operations**
How many orders were Delivered vs Cancelled? What percentage of total orders does each status represent?

---

**Q3 · Customer Behavior**
Who are the top 5 customers by total amount spent? List their names and total spend.

---

**Q4 · Operations**
What is the average delivery time in minutes across all delivered orders?

---

**Q5 · Revenue**
Which city generates the most revenue? Consider only delivered orders.

---

**Q6 · Delivery Performance**
What is the average delivery rating per agent? Rank them from best to worst.

---

**Q7 · Revenue**
Which restaurant has the highest total revenue from delivered orders?

---

**Q8 · Operations**
How many orders did each restaurant receive in total? Include cancelled orders in the count.

---

**Q9 · Customer Behavior**
How many customers signed up each month across the dataset? Which month had the highest signups?

---

**Q10 · Delivery Performance**
How many deliveries have a status of 'Failed'? Which agent was responsible?

---

**Q11 · Revenue**
What is the total revenue generated per restaurant category? Which category leads?

---

**Q12 · Operations**
Which delivery agents have handled the most orders? List the top 5.

---

## 🟡 MEDIUM (Q13–Q30)

**Q13 · Customer Behavior**
How many customers have placed more than one order? How many ordered exactly once? What does this say about retention?

---

**Q14 · Revenue**
What is the total revenue per month (Jan, Feb, Mar)? Is revenue growing or declining month over month?

---

**Q15 · Operations**
Which restaurant category has the highest average delivery time? Only consider delivered orders.

---

**Q16 · Delivery Performance**
Within each city, which delivery agent has the best average rating? Are there cities with consistently low-rated agents?

---

**Q17 · Customer Behavior**
Which customers have the highest cancellation rate (cancelled orders ÷ total orders)? Should any of them be flagged?

---

**Q18 · Revenue**
What is the average order value per city, considering only delivered orders? Which city has customers who spend the most per order?

---

**Q19 · Delivery Performance**
How many deliveries received each rating (1 through 5)? What percentage of deliveries have a rating of 3 or below?

---

**Q20 · Operations**
How many delivered orders have no rating recorded? Which agents are most affected by missing ratings — and should missing ratings be treated as neutral or excluded from performance scoring?

> ⚠ **Trap:** Missing ratings could unfairly penalise or favour agents depending on how you handle NULLs.

---

**Q21 · Customer Behavior**
For each customer who has ordered more than once, which restaurant did they order from the most? What does this reveal about loyalty to specific restaurants?

---

**Q22 · Revenue**
Compare total revenue on weekdays vs weekends. Do customers order more frequently on weekends, or do they spend more per order?

---

**Q23 · Retention**
Group customers by the year they signed up (2021, 2022, 2023). How much of the total order volume and revenue does each cohort account for? Which cohort is most active?

---

**Q24 · Operations**
List the top 10 orders with the highest delivery time. Are these clustered around specific restaurants, agents, or cities — or are they random outliers?

---

**Q25 · Delivery Performance**
Is there a pattern between how many deliveries an agent handles and their average rating? Do busier agents tend to perform worse?

---

**Q26 · Revenue**
What percentage of total revenue comes from orders above ₹1000? How many such orders exist and from which restaurants do they mostly come?

---

**Q27 · Operations**
Which restaurants have zero cancelled orders in the dataset? Is this a data quality issue, a business strength, or just low order volume?

---

**Q28 · Customer Behavior**
For each city, which restaurant category do customers order from the most? Do Pondicherry customers behave differently from Chennai customers?

---

**Q29 · Delivery Performance**
Are there any orders marked as 'Delivered' in the orders table that have no corresponding record in the deliveries table? What might cause this in a real system?

> ⚠ **Trap:** This is a data integrity check. Joining incorrectly can make this invisible.

---

**Q30 · Revenue**
How much total order revenue has each delivery agent handled? Rank them. Should agent bonuses be based on this number?

> ⚠ **Trap:** Agent revenue = sum of order amounts they delivered. Don't confuse order count with revenue.

---

## 🔴 HARD (Q31–Q50)

**Q31 · Retention**
Define a churned customer as someone who placed at least one order in January but placed zero orders in March. How many customers churned by this definition? Is this definition fair?

---

**Q32 · Revenue**
What percentage of total revenue comes from the top 3 restaurants? If those restaurants went offline, what would be the revenue impact? How dependent is the business on a small number of partners?

---

**Q33 · Operations**
The city field has inconsistent values like 'chennai', 'CHENNAI', and 'Pondy'. If you group by city without cleaning this data, how much does the revenue figure for Chennai get undercounted? Quantify the error.

> ⚠ **Trap:** Naive GROUP BY city will split Chennai into 3 separate groups and silently undercount revenue.

---

**Q34 · Customer Behavior**
Calculate a simple Customer Lifetime Value (CLV) as: average order value × number of delivered orders per customer. Who are the top 10 customers by CLV? How different is this list from the top spenders list in Q3?

---

**Q35 · Delivery Performance**
Average rating alone doesn't tell the full story. Which agents have the highest variance in ratings (sometimes 5, sometimes 1)? Who is the most consistent performer regardless of average?

---

**Q36 · Operations**
Are there any orders with status 'Cancelled' in the orders table that somehow still have a record in the deliveries table? What does this mean operationally — payment refund risk, data pipeline bug, or both?

> ⚠ **Trap:** A cancelled order with a delivery record is a serious data anomaly. A naive join can hide this entirely.

---

**Q37 · Revenue**
On which specific dates did revenue spike the most compared to the day before? Is the spike driven by order volume or by high-value individual orders? Are the spikes explainable?

---

**Q38 · Retention**
For customers who ordered more than once, what is the average number of days between their first and second order? Are customers who re-order faster also higher spenders overall?

---

**Q39 · Customer Behavior**
Are there customers ordering from restaurants in a different city than their home city? List them. Is this a data issue, or do they genuinely order cross-city? What business rule should govern this?

> ⚠ **Trap:** Requires joining customers and restaurants on city and comparing — easy to produce wrong results if JOIN order or level is off.

---

**Q40 · Delivery Performance**
Do orders with longer delivery times consistently receive lower ratings? Find the average rating for delivery time buckets: under 30 min, 30–45 min, 45–60 min, and 60+ min. Is the relationship linear?

---

**Q41 · Revenue**
If you join orders → deliveries → agents without being careful about join type and aggregation level, revenue figures can be inflated. Construct a scenario where this double-counting happens and explain exactly why it occurs and how to fix it.

> ⚠ **Trap:** Classic fan trap. One order can have multiple delivery attempts — joining at order level and then summing order_amount inflates total revenue.

---

**Q42 · Operations**
Create a simple efficiency score for each restaurant: (number of delivered orders ÷ total orders placed) × average delivery rating. Which restaurants score highest and lowest? What operational decisions would you make based on this?

---

**Q43 · Retention**
Identify customers who spent more than ₹2000 in total but placed their last order more than 45 days before the end of the dataset period. These are high-value customers showing signs of churn. How many are there and from which cities do they come?

---

**Q44 · Customer Behavior**
Segment all customers into: One-Time (1 order), Occasional (2–3 orders), Regular (4+ orders). What share of total revenue does each segment drive? If you could only run one re-engagement campaign, which segment would you target and why?

---

**Q45 · Operations**
There are orders where order_amount is NULL. If you calculate total revenue with a simple SUM, these rows are silently excluded. How much revenue is potentially missing from your reports because of this? What should the business do — impute, flag, or exclude?

> ⚠ **Trap:** SUM ignores NULLs without any warning or error. Most analysts don't notice the row count doesn't match the revenue row count.

---

**Q46 · Delivery Performance**
Are any delivery agents handling orders in a city different from the city they are registered in? List those deliveries. Is this a routing system failure, agent flexibility, or a data entry error?

> ⚠ **Trap:** Requires a multi-table join across deliveries, orders, restaurants, and agents — easy to join at the wrong level and miss mismatches.

---

**Q47 · Revenue**
Calculate the month-over-month revenue growth rate for Jan→Feb and Feb→Mar. Is the business growing? Now recalculate excluding cancelled orders and orders with NULL amounts. Does the growth story change?

> ⚠ **Trap:** Including cancelled orders in revenue is a common business reporting error that overstates performance.

---

**Q48 · Retention**
Among customers who only ordered in January and never again, what percentage had at least one cancelled order in January? Is cancellation a leading indicator of churn in this dataset?

---

**Q49 · Operations**
You are asked to build a monthly agent leaderboard. A junior analyst ranks agents purely by average rating. What are at least 3 reasons this leaderboard is misleading? Redesign the ranking criteria to be fairer and more operationally meaningful.

> ⚠ **Trap:** Agents with only 1 delivery can hold a perfect 5.0. Agents with NULL ratings look artificially better or worse. High-volume agents are structurally penalised compared to low-volume ones.

---

**Q50 · Revenue**
The CEO wants a single-page business summary for Q1 2024 (Jan–Mar). Using only this dataset, define the 6 most important KPIs you would report, the biggest risk you would flag, one growth opportunity you see, and one data quality issue that might be distorting the numbers. Justify every choice.

> ⚠ **Trap:** Open-ended. Tests whether you know what matters vs what's merely easy to compute.

---

*50 questions · 7 traps · 6 domains · 1 dataset*
