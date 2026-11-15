alter table public.properties
  add column headline text not null default '',
  add column price_max numeric(14,2),
  add constraint properties_headline_length check (char_length(headline) <= 180),
  add constraint properties_valid_price_guide check (
    price_max is null or (price_max > price and price_max <= price + 100000)
  );
