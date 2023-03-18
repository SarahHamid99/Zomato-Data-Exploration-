drop table if exists goldusers_signup;
CREATE TABLE goldusers_signup(userid integer,gold_signup_date date); 

INSERT INTO goldusers_signup(userid,gold_signup_date) 
 VALUES (1,'09-22-2017'),
(3,'04-21-2017');

drop table if exists users;
CREATE TABLE users(userid integer,signup_date date); 

INSERT INTO users(userid,signup_date) 
 VALUES (1,'09-02-2014'),
(2,'01-15-2015'),
(3,'04-11-2014');

drop table if exists sales;
CREATE TABLE sales(userid integer,created_date date,product_id integer); 

INSERT INTO sales(userid,created_date,product_id) 
 VALUES (1,'04-19-2017',2),
(3,'12-18-2019',1),
(2,'07-20-2020',3),
(1,'10-23-2019',2),
(1,'03-19-2018',3),
(3,'12-20-2016',2),
(1,'11-09-2016',1),
(1,'05-20-2016',3),
(2,'09-24-2017',1),
(1,'03-11-2017',2),
(1,'03-11-2016',1),
(3,'11-10-2016',1),
(3,'12-07-2017',2),
(3,'12-15-2016',2),
(2,'11-08-2017',2),
(2,'09-10-2018',3);


drop table if exists product;
CREATE TABLE product(product_id integer,product_name text,price integer); 

INSERT INTO product(product_id,product_name,price) 
 VALUES
(1,'p1',980),
(2,'p2',870),
(3,'p3',330);


select * from sales;
select * from product;
select * from goldusers_signup;
select * from users;

 --What is the total amount each customer spent on Zomato?
Select s.userid,SUM(p.price) As total_amount_spent
from sales as s
left join product as p
on s.product_id=p.product_id
group by s.userid

--How many days has each customer visited Zomato?
Select userid,COUNT(userid) AS total_days
from sales
group by userid

--What was the fisrt product purchased by each customer?

select *
from
(select *,rank() over (partition by userid order by created_date) AS rank
from sales) a
where a.rank=1

--What is the most purchased item on the menu and how many times was it purchased by all customers?
select top(1) product_id
from sales
group by product_id
order by count(product_id) desc

select userid,COUNT(userid) AS total_times_purchased
from sales
where product_id=(select top(1) product_id
from sales
group by product_id
order by count(product_id) desc)
group by userid

--Which item was the most popular for each customer?
select *
from
(select *,rank() over (partition by userid order by a.total_product_purchased desc) AS rnk
from 
(select userid,product_id,count(product_id) AS total_product_purchased
from sales
group by userid,product_id
) a)b
where rnk=1

--Which item was purchased first by the customer after they became a member?
select *
from
(select *,rank() over (partition by userid Order by created_date) AS rank
from
(Select s.userid,s.created_date,s.product_id,u.gold_signup_date
from sales AS s
inner join goldusers_signup AS u
ON s.userid=u.userid and s.created_date>=u.gold_signup_date
)d)e
where rank=1

--Which item was purchased just before the customer has became a member?
select *
from
(select *,rank() over (partition by userid Order by created_date desc) AS rank
from
(Select s.userid,s.created_date,s.product_id,u.gold_signup_date
from sales AS s
inner join goldusers_signup AS u
ON s.userid=u.userid and s.created_date<=u.gold_signup_date
)d)e
where rank=1

--What is the total orders and amount spent for each memeber they became a member?
select f.userid,f.total_amount_spent,g.total_number_of_orders
from (select e.userid,SUM(p.price) AS total_amount_spent
from product as p
inner join (Select s.userid,s.created_date,s.product_id,u.gold_signup_date
from sales AS s
inner join goldusers_signup AS u
ON s.userid=u.userid and s.created_date<=u.gold_signup_date) e 
ON p.product_id=e.product_id
Group by e.userid) f 
inner join (select e.userid,COUNT(e.userid) AS total_number_of_orders
from product as p
inner join (Select s.userid,s.created_date,s.product_id,u.gold_signup_date
from sales AS s
inner join goldusers_signup AS u
ON s.userid=u.userid and s.created_date<=u.gold_signup_date) e 
ON p.product_id=e.product_id
group by e.userid)g 
ON f.userid=g.userid

--If buying each product generates point for eg. 5DHS=2 Zomato points and each product has different purchasing points
--for eg. p1 5DHS=1 Zomato point , for p2 10DHS=5 Zomato points and p3 5DHS=1 Zomato point.Calculate points collected
--by each customer and for which product most points have been given until now for each customer.
select l.userid,l.product_id AS product_with_highest_points,m.total_points AS total_points_of_customer
from 
(select k.userid,k.product_id,k.points
from(select *,rank() over (partition by userid order by points desc) AS rank
from (select h.userid,h.product_id,h.total_products,total_products*price AS total_spent,
CASE
WHEN h.product_id=1 THEN ((total_products*price)/5)*1
WHEN h.product_id=2 THEN ((total_products*price)/10)*5
WHEN h.product_id=3 THEN ((total_products*price)/5)*1
END AS points
from
(select userid,product_id,COUNT(product_id) AS total_products
from sales
group by userid,product_id
)h
inner join product as p
on h.product_id=p.product_id)j)k
where rank=1) as l
inner join (select userid,SUM(points) AS total_points
from
(select h.*,p.price,total_products*price AS total_spent,
CASE
WHEN h.product_id=1 THEN ((total_products*price)/5)*1
WHEN h.product_id=2 THEN ((total_products*price)/10)*5
WHEN h.product_id=3 THEN ((total_products*price)/5)*1
END AS points
from
(select userid,product_id,COUNT(product_id) AS total_products
from sales
group by userid,product_id
)h
inner join product as p
on h.product_id=p.product_id
)i
group by userid
) as m
on l.userid=m.userid
order by points desc

--In the first one year after a customer joins the golden program (including their join date) irrespective of what the 
--customer has purchased they 5 zomato points for every 10DHS spent.Who earned more 1 or 3 and what was their point earnings
--in their first year?
select o.userid,sum(p.price) AS total_spent_in1year,(sum(p.price)/10)*5  AS total_points
from 
(select n.userid,n.gold_signup_date,m.created_date,m.product_id,DATEADD(yy,1,gold_signup_date) AS after_1year
from goldusers_signup AS n
inner join sales as m
on n.userid=m.userid) o
inner join product p
on o.product_id=p.product_id
where created_date<after_1year AND created_date>gold_signup_date
group by o.userid
order by total_points desc

--Rank all the transactions of the customers
select * ,rank() over (partition by userid order by created_date) AS rank
from sales

