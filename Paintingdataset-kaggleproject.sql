--SELECT DB_NAME() AS CurrentDatabase;
--EXEC sp_help 'canvas_size';
--EXEC sp_help 'product_size';
--select * from artist
--select * from canvas_size
--select * from image_link
--select * from museum_hours
--select * from museum
--select * from product_size
--select * from subject 
--select * from work

--1) Fetch all the paintings which are not displayed on any museums? 

select * from work where museum_id is null;

--2) Are there museuems without any paintings?

SELECT *
FROM museum
WHERE museum_id NOT IN (
    SELECT museum_id
    FROM work
    WHERE work_id IS NOT NULL
);

--3) How many paintings have an asking price of more than their regular price? 

select * from product_size
where sale_price>regular_price

--4) Identify the paintings whose asking price is less than 50% of its regular price

select * from product_size
where sale_price<(regular_price*0.5)

--5) Which canva size costs the most?

with canvas_rank_by_cost as (
select *
,rank()over(order by sale_price desc) as rnk
from product_size)

select a.size_id  --most_costly_canvas_size
from canvas_rank_by_cost a
join canvas_size b
on a.size_id =cast(b.size_id as varchar)
where rnk=1


--6) Delete duplicate records from work, product_size, subject  tables

--using self join
delete from work 
where work_id in(select a.work_id
                 from work a
                 inner join work b
                 on a.name=b.name and a.work_id>b.work_id)

--using windows function
with duplicate_cte as (
select *
,row_number() over (partition by name order by work_id) AS rw
from work
)
Delete from duplicate_cte
where rw >1;


---using unique identifier
delete from work 
	where work_id not in (select max(work_id)
						from work
						group by name );



--(ii) 
select * from product_size

delete from product_size 
	where work_id not in (select min(work_id)
						from product_size
						group by work_id, size_id );

--(iii)

	WITH CTE AS (
    SELECT
        work_id,
        subject,
        ROW_NUMBER() OVER (PARTITION BY work_id, subject ORDER BY (SELECT NULL)) AS RowNum
    FROM
        subject
)
DELETE FROM CTE WHERE RowNum > 1;

--7) Identify the museums with invalid city information in the given dataset

select * from museum
where city NOT LIKE '[0-9]%'

--9) Fetch the top 10 most famous painting subject

select * 
	from (
		select s.subject,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as ranking
		from work w
		join subject s on s.work_id=w.work_id
		group by s.subject ) A
	where ranking <= 10;

--10) Identify the museums which are open on both Sunday and Monday. Display museum name, city.

select b.name as museum_name, b.city 
from museum_hours a
inner join museum b
on a.museum_id=b.museum_id
where a.day in ('Sunday','Monday')
group by b.museum_id, b.name, b.city
having count(distinct a.day) = 2

				
--	11) How many museums are open every single day?
select count(1) 
from (select museum_id
       from museum_hours
       group by museum_id
        having count(day)=7) A	

--12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)			   

with popular_museum as (
select m.museum_id,count(w.work_id) as cnt
,dense_rank()over(order by count(w.work_id)desc) as no_of_highest_painting
from museum m 
left join work w 
on m.museum_id=w.museum_id
group by m.museum_id)

select *
from popular_museum
where no_of_highest_painting<=5

--13) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select a.full_name as artist_name
from (select a.artist_id, count(1) as no_of_painintgs
	  ,rank() over(order by count(1) desc) as rnk
	  from work w
		join artist a on a.artist_id=w.artist_id
		group by a.artist_id) x
join artist a on a.artist_id=x.artist_id
where x.rnk<=5;


--14) Display the 3 least popular canva sizes

with least_popular as (
select cs.size_id,cs.label,count(1) as no_of_paintings
, dense_rank() over(order by count(1) ) as ranking
from work w
join product_size ps on ps.work_id=w.work_id
join canvas_size cs on cast(cs.size_id as varchar) = ps.size_id
group by cs.size_id,cs.label)

select * from least_popular
where ranking<=3

--15) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

with museumtimedata as (
select museum_id, day,[open],[close]
--,concat(left([open],5),' ',right([open],2))
--,concat(left([close],5),' ',right([close],2))
--,try_CAST(CONVERT(datetime, concat(left([open],5),' ',right([open],2)), 0) as time) AS open_time
--,try_CAST(CONVERT(datetime, concat(left([close],5),' ',right([close],2)), 0) as time) AS close_time
,datediff(minute, 
        try_CAST(convert(datetime, concat(left([open],5),' ',right([open],2)), 0) as time) 
       ,try_CAST(convert(datetime, concat(left([close],5),' ',right([close],2)), 0) as time)) as duration_minutes   
from museum_hours
)
--in the above "museumtimedata" cte open and close column are in character string "10:30:AM" instead of "10:30 AM"

,rank_museum as (select md.*
,rank()over(order by md.duration_minutes desc) as rnk
from museumtimedata md
join museum m on md.museum_id=m.museum_id)

select* from
rank_museum
where rnk=1

--16) Which museum has the most no of paintingsin most popular painting style?

with pop_style as (
select style
,rank()over(order by count(1) desc) as rnk
from work
group by style
)
,rankbypainting as (select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings
,rank() over(order by count(1) desc) as rnk
from work w
join museum m on m.museum_id=w.museum_id
join pop_style ps on ps.style = w.style
where w.museum_id is not null and ps.rnk=1
group by w.museum_id, m.name,ps.style)

select museum_id, museum_name,style,no_of_paintings
from rankbypainting
where rnk=1;


--17) Find Most Popular Painting Style for Each Museum:

with cte as (select w.museum_id,m.name as museum_name,w.style, count(1) as no_of_paintings
,rank() over(order by count(1) desc) as rnk
from work w
join museum m on m.museum_id=w.museum_id
group by w.museum_id, m.name,w.style )

select * from cte
where rnk=1

--18) Identify the artists whose paintings are displayed in multiple countries

with cte as
(select distinct a.full_name as artist, w.artist_id
, m.country
from work w
join artist a on a.artist_id=w.artist_id
join museum m on m.museum_id=w.museum_id
)
select artist,count(distinct country) as no_of_countries
from cte
group by artist
having count(distinct country)>1
order by 2 desc;

--19) Display the country and the city with most no of museums.
--Output: 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.

with cte_country as (
select country, count(distinct museum_id) as cnt_country_museum
,rank() over(order by count(distinct museum_id) desc) as rnk
from museum
group by country
)
,cte_city as (
select city
,count(distinct museum_id) as cnt_city_museum
,rank() over(order by count(distinct museum_id) desc) as rnk
from museum
group by city
)
select string_agg(country.country,', ') as top_countries, string_agg(city.city,', ') as top_cities
from cte_country country
cross join cte_city city
where country.rnk = 1
and city.rnk = 1;


--20) Identify the artist and the museum where the most expensive and least expensive painting is placed.
--Display the artist name, sale_price, painting name, museum name, museum city and canvas label

with cte as (
select *
,rank() over(order by sale_price desc) as rnk
,rank() over(order by sale_price ) as rnk_asc
from product_size )
select w.name as painting
, cte.sale_price
, a.full_name as artist
, m.name as museum, m.city
, cz.label as canvas,rnk,rnk_asc
from cte
join work w on w.work_id=cte.work_id
join museum m on m.museum_id=w.museum_id
join artist a on a.artist_id=w.artist_id
join canvas_size cz on cz.size_id = cast(cte.size_id as int)
where rnk=1 or rnk_asc=1;

--21) Which country has the 5th highest no of paintings?
with cte as (
select m.country, count(w.work_id) as no_of_Paintings
,rank() over(order by count(w.work_id) desc) as rnk
from work w
join museum m on m.museum_id=w.museum_id
group by m.country
)
select country, no_of_Paintings
from cte 
where rnk=5;

--22) Which are the 3 most popular and 3 least popular painting styles?
with cte as (
select style, count(1) as cnt
,rank() over(order by count(1) desc) rnk
,rank() over(order by count(1) asc) rnk_low
,count(1) over() as no_of_records
from work
where style is not null
group by style
)

select style
,case when rnk <=3 then 'Most Popular' when rnk_low <=3 then 'Least Popular' end as remarks 
from cte
where rnk <=3
or rnk_low <=3 
 

--23) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.

with cte as (
select a.full_name, a.nationality
,count(1) as no_of_paintings
,rank() over(order by count(1) desc) as rnk
from work w
join artist a on a.artist_id=w.artist_id
join subject s on s.work_id=w.work_id
join museum m on m.museum_id=w.museum_id
where s.subject='Portraits'
and m.country != 'USA'
group by a.full_name, a.nationality
) 
select full_name as artist_name, nationality, no_of_paintings
from cte
where rnk=1;
 





 