alter table trip_stops add column if not exists address_lat double precision;
alter table trip_stops add column if not exists address_lng double precision;
