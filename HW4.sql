create table actor (
actor_id int primary key,
    first_name varchar(50),
    last_name varchar(50)
);

create table address (
address_id int primary key,
    address varchar(100),
    address2 varchar(100),
    district varchar(50),
    city_id int,
    postal_code varchar(20),
    phone varchar(20),
    foreign key (city_id) references city(city_id)
);

create table category (
category_id int primary key,
    name varchar(50)
);

create table city (
city_id int primary key,
    city varchar(50),
    country_id int,
    foreign key (country_id) references country(country_id)
);

create table country (
country_id int primary key,
    country varchar(50)
);

create table customer (
    customer_id int primary key,
    store_id int,
    first_name varchar(50),
    last_name varchar(50),
    email varchar(100),
    address_id int,
    active boolean check (active IN (0, 1)),
    foreign key (store_id) references store(store_id),
    foreign key (address_id) references address(address_id)
);

create table film (
    film_id int primary key,
    title varchar(100),
    description text,
    release_year int,
    language_id int,
    rental_duration int check (rental_duration between 2 and 8),
    rental_rate decimal(4,2) check (rental_rate between 0.99 and 6.99),
    length int check (length between 30 and 200),
    replacement_cost decimal(5,2) check (replacement_cost between 5.00 and 100.00),
    rating varchar(10) check (rating in ('PG', 'G', 'NC-17', 'PG-13', 'R')),
    special_features text,
    foreign key (language_id) references language(language_id)
);

create table film_actor (
    film_id int,
    actor_id int,
    primary key (film_id, actor_id),
    foreign key (film_id) references film(film_id),
    foreign key (actor_id) references actor(actor_id)
);

create table film_category (
    film_id int,
    category_id int,
    primary key (film_id, category_id),
    foreign key (film_id) references film(film_id),
    foreign key (category_id) references category(category_id)
);

create table inventory (
    inventory_id int primary key,
    film_id int,
    store_id int,
    foreign key (film_id) references film(film_id),
    foreign key (store_id) references store(store_id)
);

create table rental (
    rental_id int primary key,
    rental_date timestamp,
    inventory_id int,
    customer_id int,
    return_date timestamp,
    staff_id int,
    unique (rental_date, inventory_id, customer_id),
    foreign key (inventory_id) references inventory(inventory_id),
    foreign key (customer_id) references customer(customer_id),
    foreign key (staff_id) references staff(staff_id)
);

create table staff (
    staff_id int primary key,
    first_name varchar(50),
    last_name varchar(50),
    address_id int,
    email varchar(100),
    store_id int,
    username varchar(50),
    password varchar(50),
    foreign key (address_id) references address(address_id),
    foreign key (store_id) references store(store_id)
);

create table store (
    store_id int primary key,
    address_id int,
    foreign key (address_id) references address(address_id)
);

create table language (
    language_id int primary key,
    name varchar(50)
);

create table payment (
    payment_id int primary key,
    customer_id int,
    staff_id int,
    rental_id int,
    amount decimal(6,2) check (amount >= 0),
    payment_date timestamp,
    foreign key (customer_id) references customer(customer_id),
    foreign key (staff_id) references staff(staff_id),
    foreign key (rental_id) references rental(rental_id)
);

-- 1. average film length
SELECT 
  c.name AS category,                     -- Category name 
  ROUND(AVG(f.length), 2) AS avg_length_minutes 
FROM category c                          
JOIN film_category fc ON fc.category_id = c.category_id  -- Join to connect categories with films
JOIN film f ON f.film_id = fc.film_id                  -- Join to get each films length
GROUP BY c.name                           
ORDER BY c.name;                         

-- 2 Which categories have the longest and shortest average film lengths?
WITH avg_lengths AS (
  SELECT 
    c.name AS category,                   -- Category name
    AVG(f.length) AS avg_len              -- Average film length
  FROM category c
  JOIN film_category fc ON fc.category_id = c.category_id  -- Join to link films and categories
  JOIN film f ON f.film_id = fc.film_id                    -- Get each film’s length
  GROUP BY c.name                        -- Group by category
)
SELECT 
  'longest' AS type,               
  category, 
  ROUND(avg_len, 2) AS avg_length_minutes
FROM avg_lengths
WHERE avg_len = (SELECT MAX(avg_len) FROM avg_lengths)     -- Long category
UNION ALL
SELECT 
  'shortest', category, ROUND(avg_len, 2)
FROM avg_lengths
WHERE avg_len = (SELECT MIN(avg_len) FROM avg_lengths);    -- Short catgory 


-- 3  rented at least one Action movie but not comedy or classics

SELECT DISTINCT 
  cu.customer_id,                        -- Customer ID
  cu.first_name,                         -- Customer first name
  cu.last_name                           -- Customer last name
FROM customer cu                         
WHERE EXISTS (                           
  SELECT 1
  FROM rental r
  JOIN inventory i ON i.inventory_id = r.inventory_id     -- Connect rentals to inventory
  JOIN film_category fc ON fc.film_id = i.film_id         -- Link inventory to films
  JOIN category c ON c.category_id = fc.category_id       
  WHERE r.customer_id = cu.customer_id
    AND c.name = 'Action'                -- Must have rented an Action movie
)
AND NOT EXISTS (                        --  cannot rent comedy or classics
  SELECT 1
  FROM rental r
  JOIN inventory i ON i.inventory_id = r.inventory_id
  JOIN film_category fc ON fc.film_id = i.film_id
  JOIN category c ON c.category_id = fc.category_id
  WHERE r.customer_id = cu.customer_id
    AND c.name IN ('Comedy', 'Classics') 
)
ORDER BY cu.last_name, cu.first_name;    


-- 4. actor in the most english films
WITH actor_counts AS (
  SELECT 
    a.actor_id,                           -- Actor ID
    a.first_name,                         -- First name
    a.last_name,                          -- Last name
    COUNT(DISTINCT f.film_id) AS english_films  --  distinct english films
  FROM actor a
  JOIN film_actor fa ON fa.actor_id = a.actor_id          
  JOIN film f ON f.film_id = fa.film_id                  
  JOIN language l ON l.language_id = f.language_id        
  WHERE l.name = 'English'                               -- filter only english
  GROUP BY a.actor_id, a.first_name, a.last_name          -- group by actor
)
SELECT 
  actor_id, 
  first_name, 
  last_name, 
  english_films
FROM actor_counts
WHERE english_films = (SELECT MAX(english_films) FROM actor_counts)  
ORDER BY last_name, first_name;             


-- 5.   distinct films rented for exactly 10 days from the store managed by Mike
SELECT 
  COUNT(DISTINCT i.film_id) AS distinct_movies_10_days   -- Count unique film IDs
FROM rental r
JOIN inventory i ON i.inventory_id = r.inventory_id      
JOIN store s ON s.store_id = i.store_id                  
WHERE s.store_id = (
  SELECT st.store_id
  FROM staff st
  WHERE st.first_name = 'Mike'                           -- Find store managed by mike
  LIMIT 1
)
AND r.return_date IS NOT NULL                            
AND DATEDIFF(r.return_date, r.rental_date) = 10;         -- rented exactly for 10 days


-- 6.  largest number of actors and list all actors who appear in those movies.

WITH cast_sizes AS (
  SELECT 
    fa.film_id,                       -- Film ID
    COUNT(*) AS cast_count            -- Number of actors in each film
  FROM film_actor fa
  GROUP BY fa.film_id                 -- Group by film to get cast size
),
max_cast AS (
  SELECT film_id
  FROM cast_sizes
  WHERE cast_count = (SELECT MAX(cast_count) FROM cast_sizes)  
)
SELECT DISTINCT 
  a.actor_id,                        
  a.first_name,                       
  a.last_name
FROM max_cast mc
JOIN film_actor fa ON fa.film_id = mc.film_id   -- Join with film_actor to find the cast
JOIN actor a ON a.actor_id = fa.actor_id        
ORDER BY a.last_name, a.first_name;          



