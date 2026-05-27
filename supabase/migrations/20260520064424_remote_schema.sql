
  create table "public"."contractors" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "name" text not null,
    "phone" text not null default ''::text,
    "email" text not null default ''::text,
    "specialty" text not null default ''::text,
    "notes" text not null default ''::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."contractors" enable row level security;


  create table "public"."house_info_items" (
    "id" uuid not null default gen_random_uuid(),
    "property_id" uuid not null,
    "category" text not null default 'Other'::text,
    "title" text not null default ''::text,
    "description" text not null default ''::text,
    "brand" text not null default ''::text,
    "model" text not null default ''::text,
    "color" text not null default ''::text,
    "location" text not null default ''::text,
    "purchase_date" date,
    "warranty" text not null default ''::text,
    "notes" text not null default ''::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."house_info_items" enable row level security;


  create table "public"."insurances" (
    "id" uuid not null default gen_random_uuid(),
    "property_id" uuid not null,
    "carrier" text not null default ''::text,
    "policy_number" text not null default ''::text,
    "policy_type" text not null default 'Homeowner''s'::text,
    "premium" numeric not null default 0,
    "premium_frequency" text not null default 'Annually'::text,
    "deductible" numeric not null default 0,
    "coverage_amount" numeric not null default 0,
    "start_date" date not null,
    "expiration_date" date not null,
    "notes" text not null default ''::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."insurances" enable row level security;


  create table "public"."mortgages" (
    "id" uuid not null default gen_random_uuid(),
    "property_id" uuid not null,
    "lender" text not null default ''::text,
    "original_amount" double precision not null default 0,
    "current_balance" double precision not null default 0,
    "interest_rate" double precision not null default 0,
    "monthly_payment" double precision not null default 0,
    "start_date" date not null,
    "term_years" integer not null default 30,
    "loan_type" text not null default '30-Year Fixed'::text,
    "notes" text not null default ''::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."mortgages" enable row level security;


  create table "public"."properties" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "name" text not null default ''::text,
    "address" text not null default ''::text,
    "city" text not null default ''::text,
    "state" text not null default ''::text,
    "zip_code" text not null default ''::text,
    "purchase_price" double precision not null default 0,
    "current_value" double precision not null default 0,
    "purchase_date" date not null,
    "property_type" text not null default 'Single Family'::text,
    "ownership_type" text not null default 'primaryResidence'::text,
    "square_footage" double precision not null default 0,
    "bedrooms" integer not null default 0,
    "bathrooms" double precision not null default 0,
    "year_built" integer not null default 0,
    "notes" text not null default ''::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."properties" enable row level security;


  create table "public"."repairs" (
    "id" uuid not null default gen_random_uuid(),
    "property_id" uuid not null,
    "title" text not null default ''::text,
    "description" text not null default ''::text,
    "cost" double precision not null default 0,
    "date" date not null,
    "contractor" text not null default ''::text,
    "status" text not null default 'Pending'::text,
    "category" text not null default 'General'::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."repairs" enable row level security;

CREATE UNIQUE INDEX contractors_pkey ON public.contractors USING btree (id);

CREATE UNIQUE INDEX house_info_items_pkey ON public.house_info_items USING btree (id);

CREATE UNIQUE INDEX insurances_pkey ON public.insurances USING btree (id);

CREATE UNIQUE INDEX mortgages_pkey ON public.mortgages USING btree (id);

CREATE UNIQUE INDEX properties_pkey ON public.properties USING btree (id);

CREATE UNIQUE INDEX repairs_pkey ON public.repairs USING btree (id);

alter table "public"."contractors" add constraint "contractors_pkey" PRIMARY KEY using index "contractors_pkey";

alter table "public"."house_info_items" add constraint "house_info_items_pkey" PRIMARY KEY using index "house_info_items_pkey";

alter table "public"."insurances" add constraint "insurances_pkey" PRIMARY KEY using index "insurances_pkey";

alter table "public"."mortgages" add constraint "mortgages_pkey" PRIMARY KEY using index "mortgages_pkey";

alter table "public"."properties" add constraint "properties_pkey" PRIMARY KEY using index "properties_pkey";

alter table "public"."repairs" add constraint "repairs_pkey" PRIMARY KEY using index "repairs_pkey";

alter table "public"."contractors" add constraint "contractors_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."contractors" validate constraint "contractors_user_id_fkey";

alter table "public"."house_info_items" add constraint "house_info_items_property_id_fkey" FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE not valid;

alter table "public"."house_info_items" validate constraint "house_info_items_property_id_fkey";

alter table "public"."insurances" add constraint "insurances_property_id_fkey" FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE not valid;

alter table "public"."insurances" validate constraint "insurances_property_id_fkey";

alter table "public"."mortgages" add constraint "mortgages_property_id_fkey" FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE not valid;

alter table "public"."mortgages" validate constraint "mortgages_property_id_fkey";

alter table "public"."properties" add constraint "properties_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."properties" validate constraint "properties_user_id_fkey";

alter table "public"."repairs" add constraint "repairs_property_id_fkey" FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE not valid;

alter table "public"."repairs" validate constraint "repairs_property_id_fkey";

grant delete on table "public"."contractors" to "anon";

grant insert on table "public"."contractors" to "anon";

grant references on table "public"."contractors" to "anon";

grant select on table "public"."contractors" to "anon";

grant trigger on table "public"."contractors" to "anon";

grant truncate on table "public"."contractors" to "anon";

grant update on table "public"."contractors" to "anon";

grant delete on table "public"."contractors" to "authenticated";

grant insert on table "public"."contractors" to "authenticated";

grant references on table "public"."contractors" to "authenticated";

grant select on table "public"."contractors" to "authenticated";

grant trigger on table "public"."contractors" to "authenticated";

grant truncate on table "public"."contractors" to "authenticated";

grant update on table "public"."contractors" to "authenticated";

grant delete on table "public"."contractors" to "service_role";

grant insert on table "public"."contractors" to "service_role";

grant references on table "public"."contractors" to "service_role";

grant select on table "public"."contractors" to "service_role";

grant trigger on table "public"."contractors" to "service_role";

grant truncate on table "public"."contractors" to "service_role";

grant update on table "public"."contractors" to "service_role";

grant delete on table "public"."house_info_items" to "anon";

grant insert on table "public"."house_info_items" to "anon";

grant references on table "public"."house_info_items" to "anon";

grant select on table "public"."house_info_items" to "anon";

grant trigger on table "public"."house_info_items" to "anon";

grant truncate on table "public"."house_info_items" to "anon";

grant update on table "public"."house_info_items" to "anon";

grant delete on table "public"."house_info_items" to "authenticated";

grant insert on table "public"."house_info_items" to "authenticated";

grant references on table "public"."house_info_items" to "authenticated";

grant select on table "public"."house_info_items" to "authenticated";

grant trigger on table "public"."house_info_items" to "authenticated";

grant truncate on table "public"."house_info_items" to "authenticated";

grant update on table "public"."house_info_items" to "authenticated";

grant delete on table "public"."house_info_items" to "service_role";

grant insert on table "public"."house_info_items" to "service_role";

grant references on table "public"."house_info_items" to "service_role";

grant select on table "public"."house_info_items" to "service_role";

grant trigger on table "public"."house_info_items" to "service_role";

grant truncate on table "public"."house_info_items" to "service_role";

grant update on table "public"."house_info_items" to "service_role";

grant delete on table "public"."insurances" to "anon";

grant insert on table "public"."insurances" to "anon";

grant references on table "public"."insurances" to "anon";

grant select on table "public"."insurances" to "anon";

grant trigger on table "public"."insurances" to "anon";

grant truncate on table "public"."insurances" to "anon";

grant update on table "public"."insurances" to "anon";

grant delete on table "public"."insurances" to "authenticated";

grant insert on table "public"."insurances" to "authenticated";

grant references on table "public"."insurances" to "authenticated";

grant select on table "public"."insurances" to "authenticated";

grant trigger on table "public"."insurances" to "authenticated";

grant truncate on table "public"."insurances" to "authenticated";

grant update on table "public"."insurances" to "authenticated";

grant delete on table "public"."insurances" to "service_role";

grant insert on table "public"."insurances" to "service_role";

grant references on table "public"."insurances" to "service_role";

grant select on table "public"."insurances" to "service_role";

grant trigger on table "public"."insurances" to "service_role";

grant truncate on table "public"."insurances" to "service_role";

grant update on table "public"."insurances" to "service_role";

grant delete on table "public"."mortgages" to "anon";

grant insert on table "public"."mortgages" to "anon";

grant references on table "public"."mortgages" to "anon";

grant select on table "public"."mortgages" to "anon";

grant trigger on table "public"."mortgages" to "anon";

grant truncate on table "public"."mortgages" to "anon";

grant update on table "public"."mortgages" to "anon";

grant delete on table "public"."mortgages" to "authenticated";

grant insert on table "public"."mortgages" to "authenticated";

grant references on table "public"."mortgages" to "authenticated";

grant select on table "public"."mortgages" to "authenticated";

grant trigger on table "public"."mortgages" to "authenticated";

grant truncate on table "public"."mortgages" to "authenticated";

grant update on table "public"."mortgages" to "authenticated";

grant delete on table "public"."mortgages" to "service_role";

grant insert on table "public"."mortgages" to "service_role";

grant references on table "public"."mortgages" to "service_role";

grant select on table "public"."mortgages" to "service_role";

grant trigger on table "public"."mortgages" to "service_role";

grant truncate on table "public"."mortgages" to "service_role";

grant update on table "public"."mortgages" to "service_role";

grant delete on table "public"."properties" to "anon";

grant insert on table "public"."properties" to "anon";

grant references on table "public"."properties" to "anon";

grant select on table "public"."properties" to "anon";

grant trigger on table "public"."properties" to "anon";

grant truncate on table "public"."properties" to "anon";

grant update on table "public"."properties" to "anon";

grant delete on table "public"."properties" to "authenticated";

grant insert on table "public"."properties" to "authenticated";

grant references on table "public"."properties" to "authenticated";

grant select on table "public"."properties" to "authenticated";

grant trigger on table "public"."properties" to "authenticated";

grant truncate on table "public"."properties" to "authenticated";

grant update on table "public"."properties" to "authenticated";

grant delete on table "public"."properties" to "service_role";

grant insert on table "public"."properties" to "service_role";

grant references on table "public"."properties" to "service_role";

grant select on table "public"."properties" to "service_role";

grant trigger on table "public"."properties" to "service_role";

grant truncate on table "public"."properties" to "service_role";

grant update on table "public"."properties" to "service_role";

grant delete on table "public"."repairs" to "anon";

grant insert on table "public"."repairs" to "anon";

grant references on table "public"."repairs" to "anon";

grant select on table "public"."repairs" to "anon";

grant trigger on table "public"."repairs" to "anon";

grant truncate on table "public"."repairs" to "anon";

grant update on table "public"."repairs" to "anon";

grant delete on table "public"."repairs" to "authenticated";

grant insert on table "public"."repairs" to "authenticated";

grant references on table "public"."repairs" to "authenticated";

grant select on table "public"."repairs" to "authenticated";

grant trigger on table "public"."repairs" to "authenticated";

grant truncate on table "public"."repairs" to "authenticated";

grant update on table "public"."repairs" to "authenticated";

grant delete on table "public"."repairs" to "service_role";

grant insert on table "public"."repairs" to "service_role";

grant references on table "public"."repairs" to "service_role";

grant select on table "public"."repairs" to "service_role";

grant trigger on table "public"."repairs" to "service_role";

grant truncate on table "public"."repairs" to "service_role";

grant update on table "public"."repairs" to "service_role";


  create policy "Users manage own contractors"
  on "public"."contractors"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users manage own house info"
  on "public"."house_info_items"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.properties
  WHERE ((properties.id = house_info_items.property_id) AND (properties.user_id = auth.uid())))))
with check ((EXISTS ( SELECT 1
   FROM public.properties
  WHERE ((properties.id = house_info_items.property_id) AND (properties.user_id = auth.uid())))));



  create policy "Users can manage their own insurances"
  on "public"."insurances"
  as permissive
  for all
  to public
using ((property_id IN ( SELECT properties.id
   FROM public.properties
  WHERE (properties.user_id = auth.uid()))));



  create policy "Users manage own mortgages"
  on "public"."mortgages"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.properties
  WHERE ((properties.id = mortgages.property_id) AND (properties.user_id = auth.uid())))))
with check ((EXISTS ( SELECT 1
   FROM public.properties
  WHERE ((properties.id = mortgages.property_id) AND (properties.user_id = auth.uid())))));



  create policy "Users manage own properties"
  on "public"."properties"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users manage own repairs"
  on "public"."repairs"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.properties
  WHERE ((properties.id = repairs.property_id) AND (properties.user_id = auth.uid())))))
with check ((EXISTS ( SELECT 1
   FROM public.properties
  WHERE ((properties.id = repairs.property_id) AND (properties.user_id = auth.uid())))));



