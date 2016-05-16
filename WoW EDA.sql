
DROP TABLE IF EXISTS user_table_ncsoft;

DROP TYPE IF EXISTS urace;
CREATE TYPE urace AS ENUM ('Blood Elf', 'Orc', 'Tauren', 'Troll', 'Undead');

DROP TYPE IF EXISTS uclass;
CREATE TYPE uclass AS ENUM('Death Knight', 'Druid', 'Hunter', 'Mage',
    'Paladin', 'Priest', 'Rogue', 'Shaman', 'Warlock', 'Warrior');

CREATE TABLE user_table_ncsoft(
query_time timestamp,
avatar_id int,
guild_id int,
user_level int,
user_race urace,
user_class uclass,
game_zone varchar
);

CREATE INDEX user_table_ncsoft_idx_game_zone ON user_table_ncsoft (game_zone varchar_pattern_ops);

COPY user_table_ncsoft FROM '/Users/yumingfang/wowah/WoWAH/user_table' DELIMITER ',' CSV HEADER;

-- daily active avatar number
COPY(select date_trunc('day', query_time) as day,
count( distinct avatar_id)
from user_table_ncsoft
group by date_trunc('day', query_time)
order by date_trunc('day', query_time) asc)
TO '/Users/yumingfang/wowah/WoWAH/user_by_day' with CSV HEADER;

-- number of active avatar by hour duing 24 hrs period
COPY(select date_part('hour', dt) as mon,
avg(count_hr) from(
select date_trunc('hour', query_time) as dt,
count(distinct avatar_id) as count_hr
from user_table_ncsoft
group by date_trunc('hour', query_time)) as inner_q
 group by date_part('hour', dt)
 order by date_part('hour', dt)
 asc)
 TO '/Users/yumingfang/wowah/WoWAH/avg_hr' with CSV HEADER;

--  number of active avatar by day of week
COPY(select date_part('dow', dt) as dw,
avg(count_daily) from(
select date_trunc('day',query_time) as dt,
count(distinct avatar_id) count_daily
from user_table_ncsoft
group by dt) as inner_q
 group by dw
 order by dw
 asc)
 TO '/Users/yumingfang/wowah/WoWAH/user_avg_dow' with CSV HEADER;

-- number of active avatar per game zone
select count(distinct avatar_id),
game_zone
from user_table_ncsoft
group by game_zone
order by count(distinct avatar_id);

-- average daily gaming time per avatar, in mins
COPY(select avatar_id,
round(sum(case when query_time - past_time < '15 minutes'::interval and
 query_time - past_time > '5 minutes' ::interval then 10 else 0 end)/
 count(distinct date_trunc('day', query_time))::numeric , 0) as avg_time
 from
(select avatar_id,
query_time,
lag(query_time) over (partition by avatar_id order by query_time asc) as past_time
from user_table_ncsoft) as inner_q1
group by avatar_id
having max(query_time) - min(query_time) > '0'::interval)
TO '/Users/yumingfang/wowah/WoWAH/dailyeng_user' with CSV HEADER;

-- avatar with guild
COPY(select distinct avatar_id,
guild_id
from user_table_ncsoft)
TO '/Users/yumingfang/wowah/WoWAH/id_guild' with CSV HEADER;

-- number of avatar for each race
select user_race,
count(distinct avatar_id)
from user_table_ncsoft
group by user_race;

-- number of avatar for each class
select user_class,
count(distinct avatar_id)
from user_table_ncsoft
group by user_class
order by count(distinct avatar_id);

-- how quickly an user make progression to the next level
COPY(
select user_level,
avg(time_level)
from(
select avatar_id,
user_level,
sum(case when query_time - past_time < '15 minutes'::interval and
 query_time - past_time > '5 minutes' ::interval then 10 else 0 end) as time_level
 from(
select avatar_id,
user_level,
query_time,
lag(query_time) over (partition by avatar_id, user_level order by query_time asc) as past_time,
max(user_level) over (partition by avatar_id) as mx_level
from user_table_ncsoft) as inner_q1
where user_level < mx_level
group by avatar_id, user_level) as inner_q2
group by user_level
order by user_level)
TO '/Users/yumingfang/wowah/WoWAH/progression_time' with CSV HEADER;

-- progression rate per game level
COPY(select user_level,
sum(case when mx_rank - user_level > 0 then 1 else 0 end) as pro,
count(avatar_id) as tot
from(
select distinct avatar_id, user_level, mx_rank from(
select avatar_id, user_level,
max(user_level) over (partition by avatar_id) as mx_rank
from user_table_ncsoft) as inner_q1) as inner_q2
group by user_level
order by user_level)
TO '/Users/yumingfang/wowah/WoWAH/progression_rate' with CSV HEADER;

-- average daily gaming time and monthly gaming density per user
COPY(select avatar_id,
mon,
sum(case when query_time - past_time < '15 minutes'::interval and
 query_time - past_time > '5 minutes' ::interval then 10 else 0 end)/
 count(distinct date_trunc('day', query_time))::numeric as daily_eng,
 count(distinct date_trunc('day', query_time))/90::numeric as density_mon
 from
(select avatar_id,
query_time,
lag(query_time) over (partition by avatar_id order by query_time asc) as past_time,
date_trunc('quarter', query_time) as mon
from user_table_ncsoft) as inner_q1
group by avatar_id, mon)
TO '/Users/yumingfang/wowah/WoWAH/user_eng_quarter' with CSV HEADER;

-- avatar first seen and last seen during the sampling period (2006-2009)
COPY(select avatar_id,
min(query_time) as first_seen,
max(query_time) as last_seen,
extract(epoch from (max(query_time) - min(query_time))/(3600*24)) as tot_day
from user_table_ncsoft
group by avatar_id
having extract(epoch from (max(query_time) - min(query_time))/(3600*24)) > 0)
TO '/Users/yumingfang/wowah/WoWAH/user_duration' with CSV HEADER;


-- generate features for user segmentation
COPY(select avatar_id,
mon,
sum(case when query_time - past_time < '15 minutes'::interval and
 query_time - past_time > '5 minutes' ::interval then 10 else 0 end)/
 count(distinct date_trunc('day', query_time))::numeric as daily_eng,
 count(distinct date_trunc('day', query_time))/30::numeric as density_mon
 from
(select avatar_id,
query_time,
lag(query_time) over (partition by avatar_id order by query_time asc) as past_time,
date_trunc('month', query_time) as mon
from user_table_ncsoft) as inner_q1
group by avatar_id, mon)
TO '/Users/yumingfang/wowah/WoWAH/user_eng_mon' with CSV HEADER;

-- create labels
COPY (select distinct avatar_id,
date_trunc('week', query_time) as wk,
case when count(avater_id) over (partition by avatar_id, date_trunc('week', query_time)
order by date_trunc('week', query_time) asc) is not null then 1 else 0 end as label
from user_table_ncsoft
where date_trunc('month', query_time) > '2008-03-01 00:00:00'
and date_trunc('month', query_time) < '2008-06-01 00:00:00')
TO '/Users/yumingfang/wowah/WoWAH/label' with CSV HEADER;