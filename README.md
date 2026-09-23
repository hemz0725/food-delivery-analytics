# Food Delivery Analytics — Q1 2024 Business Review

An investigation into a **38% quarter-over-quarter revenue decline** using SQL, business segmentation, and root-cause analysis on a food delivery dataset.

**Tools:** PostgreSQL · SQL (joins, CTEs, window functions, aggregations)

---

## The Findings

- **Revenue fell 38%** (₹22,140 → ₹13,715) across Q1 2024 — driven by both fewer orders (30 → 20) and lower average order value (₹738 → ₹722).
- **Chennai accounted for 70% of order volume loss** and **52.5% of revenue decline**, despite being 1 of 6 regions.
- **The decline in Chennai was driven by falling order frequency (1.36 → 0.92 orders per customer)** — not customer churn. Active customer count stayed stable (14 → 14 → 13).
- **Service quality did not explain the decline.** Churned customers had higher AOV, higher ratings, and faster delivery times than retained customers.
- **Root cause cannot be definitively established** from this dataset — restaurant availability, pricing, promotions, and competitor activity are not captured.

---

## Business Context

The dataset covers six Indian cities (Chennai, Bangalore, Coimbatore, Hyderabad, Madurai, Pondicherry) over Q1 2024, with orders, customers, restaurants, delivery agents, and delivery performance metrics.

**The question:** Why did revenue fall 38% in three months?

**The decision:** Where should the business focus to reverse the trend?

---

## Data

| Table | Contents |
|---|---|
| orders | Order details — amount, date, status, restaurant, delivery time |
| customers | Customer signup, city, name |
| restaurants | Restaurant details — category, city |
| deliveries | Delivery records — agent, status, rating |
| delivery_agents | Agent details — name, city |

**Dataset size:** Small (< 100 orders). Findings are directional, not statistically conclusive.

---

## Methodology

The analysis uses a **KPI → Driver → Root Cause** framework:

1. **Define the headline metric** — revenue decline
2. **Decompose into drivers** — order volume × average order value
3. **Segment by dimension** — region, restaurant, customer
4. **Identify the concentration** — where the decline is largest
5. **Investigate cause** — frequency vs churn, service vs external factors
6. **State limitations** — what the data can and cannot prove

---

## Key Analyses

### 1. Revenue Decomposition

| Metric | Jan | Feb | Mar |
|---|---|---|---|
| Revenue (GMV) | ₹22,140 | ₹20,840 | ₹13,715 |
| Orders | 30 | 27 | 20 |
| Avg Order Value | ₹738 | ₹772 | ₹722 |
| Active Customers | 23 | 24 | 20 |

Revenue growth: **−5.9% (Jan→Feb)** and **−34.2% (Feb→Mar)**.

Both drivers fell — fewer orders *and* smaller orders.

### 2. Regional Concentration

Segmented order volume and revenue by region:

| Region | Order Loss (Jan→Mar) | Revenue Loss |
|---|---|---|
| **Chennai** | 7 orders (70% of total loss) | ₹4,425 (52.5% of total) |
| Coimbatore | 1 | Small |
| Bangalore | 1 | Small |
| Others | 0 | Small |

**Chennai is the primary driver.**

### 3. Chennai Investigation — Churn vs Frequency

| Metric | Jan | Feb | Mar |
|---|---|---|---|
| Active Customers (Chennai) | 14 | 14 | 13 |
| Orders per Customer | 1.36 | 1.07 | 0.92 |

**Customer count is stable. Order frequency is falling.**

This means the decline is not driven by customers leaving — it's driven by existing customers ordering less often.

### 4. Service Quality Hypothesis — Rejected

Within Chennai:
- Restaurant-level decline was spread across multiple restaurants, not concentrated
- Adyar Ananda Bhavan (highest rating, fastest delivery) also declined
- Pizza Hut (weaker metrics) declined most, but this alone doesn't explain the pattern

**Company-wide:** churned customers had *higher* AOV, *higher* ratings, and *faster* delivery than retained customers.

**Conclusion:** Service quality does not explain the decline.

---

## Root Cause — Not Established

The data shows:
- Revenue fell 38%
- Chennai drove 52.5% of the decline
- Order frequency (not churn) caused Chennai's decline

The data does **not** show:
- Why order frequency fell
- Whether restaurant availability changed
- Whether pricing changed
- Whether competitors launched promotions

**Hypotheses to investigate:** restaurant availability/operating hours, promotions, competitor activity, pricing changes during Feb–Mar.

---

## Recommendations

1. **Prioritize Chennai** for further investigation — it drives most of the decline.
2. **Investigate restaurant availability and operating factors** in Chennai, especially for high-performers like Adyar Ananda Bhavan.
3. **Review Pizza Hut's service metrics** — it lost the most orders within Chennai.
4. **Examine external factors** — competitor activity, pricing changes, promotions, customer offers in Feb–Mar.
5. **Expand the dataset** with restaurant availability status, promotions, marketing activity, and competitor pricing to move from directional to conclusive findings.

---

## SQL Practice — 50 Business Questions

This project also includes **50 SQL business questions** solved across easy / medium / hard tiers, covering:

- Joins, CTEs, subqueries
- Window functions (rank, lag, row_number, dense_rank)
- Aggregations, conditional logic
- Data-quality traps: NULL handling, fan traps, join-level inflation

See [`questions.md`](questions.md) and [`sql/`](sql/).

---

## Limitations

- **Small dataset** (< 100 orders). Findings are directional, not statistically significant.
- **Missing variables** — restaurant availability, promotions, competitor pricing, marketing activity.
- **Root cause not established** — the analysis narrows the search but cannot close it.
- **Churn definition** (Jan active, Mar inactive) is coarse — one month of inactivity does not prove churn.

---

## Files

- [`business_summary.md`](business_summary.md) — full Q1 business review
- [`questions.md`](questions.md) — 50-question bank
- [`sql/easy.sql`](sql/easy.sql) — Q1–Q12
- [`sql/medium.sql`](sql/medium.sql) — Q13–Q30
- [`sql/hard.sql`](sql/hard.sql) — Q31–Q50

---

## Author

**Hemanthkumar M**
B.Com (General), Loyola College, Chennai
[LinkedIn](https://www.linkedin.com/in/hemanthkumar-m-13082b23b) · [GitHub](https://github.com/Hemz0725)
