create or replace table app_risk.app_risk_test.api_seller_batch_v2 as
select distinct unit_token
    ,case when payment_trx_recognized_date between '2019-01-01' and '2019-03-31' then '2019Q1'
    when payment_trx_recognized_date between '2021-01-01' and '2021-03-31' then '2021Q1'
    else null end as batch
    from app_bi.pentagon.fact_payment_transactions fpt
    where currency_code = 'USD' and is_gpv = 1
    and payment_trx_recognized_date between '2019-01-01' and '2021-06-30'
    and product_name like '%API%'
;
 
create or replace table app_risk.app_risk_test.api_seller_gpv_v2 as
select 
distinct sds.user_token
,sum(case when payment_trx_recognized_date between '2019-01-01' and '2019-03-31' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2019Q1_GPV"
,sum(case when payment_trx_recognized_date between '2021-01-01' and '2021-03-31' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2021Q1_GPV"
from app_bi.pentagon.aggregate_seller_daily_payment_summary sds
where sds.user_token in (select distinct unit_token 
                     from app_risk.app_risk_test.api_seller_batch_v2)
                    group by 1
;

create or replace table app_risk.app_risk_test.api_seller_cb_loss_v2 as
select distinct user_token
,sum(case when payment_created_at between '2019-01-01' and '2019-03-31' then chargeback_cents/100 else 0 end) as "2019Q1_cb"
,sum(case when payment_created_at between '2021-01-01' and '2021-03-31' then chargeback_cents/100 else 0 end) as "2021Q1_cb"
,sum(case when payment_created_at between '2019-01-01' and '2019-03-31' then loss_cents/100 else 0 end) as "2019Q1_loss"
,sum(case when payment_created_at between '2021-01-01' and '2021-03-31' then loss_cents/100 else 0 end) as "2021Q1_loss"
from app_risk.app_risk.chargebacks 
where user_token in (select distinct unit_token 
                     from app_risk.app_risk_test.api_seller_batch_V2)
                    group by 1
;

create or replace table app_risk.app_risk_test.api_seller_trend_v2 as
select 
batch
,batch.unit_token
,case when batch = '2019Q1' then "2019Q1_GPV"
when batch = '2021Q1' then "2021Q1_GPV"
end as gpv_dllr
,case when gpv_dllr*4 < 100000 then '0.<100k'
when gpv_dllr*4 < 250000 then '1.100k - 250k'
when gpv_dllr*4 < 1000000 then '2.250k - 1M'
when gpv_dllr*4 < 2000000 then '3.1M - 2M'
when gpv_dllr*4 >= 2000000 then '4.over 2M'
end as annualized_gpv_band
,case when batch = '2019Q1' then "2019Q1_CB"
when batch = '2021Q1' then "2021Q1_CB"
end as cb_dllr
,case when batch = '2019Q1' then "2019Q1_LOSS"
when batch = '2021Q1' then "2021Q1_LOSS"
end as loss_dllr
from app_risk.app_risk_test.API_SELLER_BATCH_V2 batch
left join app_risk.app_risk_test.API_SELLER_GPV_V2 gpv
on batch.unit_token = gpv.user_token
left join app_risk.app_risk_test.api_seller_cb_loss_V2 cb
on batch.unit_token = cb.user_token
where batch is not null
;

--presale exposure
create or replace table app_risk.app_risk_test.api_seller_intermediate_v2 as
select seller.*, exp.non_delivery_exposure as presale_dllr
/*batch
,annualized_gpv_band
,count(distinct unit_token)
,sum(non_delivery_exposure) as presale_dllr*/
from app_risk.app_risk_test.api_seller_trend_v2 seller
left join app_risk.app_risk.intl_portfolio_exposure exp
on seller.unit_token = exp.user_token
where cohort_date = '2021-03-29' 
and batch = '2021Q1'
;

create or replace table app_risk.app_risk_test.api_seller_intermediate_v2_part2 as
select seller.*, exp.non_delivery_exposure as presale_dllr
from app_risk.app_risk_test.api_seller_trend_v2 seller
left join app_risk.app_risk.intl_portfolio_exposure exp
on seller.unit_token = exp.user_token

where cohort_date = '2019-03-25' 
and batch = '2019Q1'

;

create or replace table app_risk.app_risk_test.api_seller_intermediate_final as
select * from app_risk.app_risk_test.api_seller_intermediate_v2
union
select * from app_risk.app_risk_test.api_seller_intermediate_v2_part2
;

create or replace table app_risk.app_risk_test.api_seller_final_v2 as
select * from (
select 
seller.unit_token
,case when CREDIT_RISK_RATING = 'MINIMAL' THEN 1
when CREDIT_RISK_RATING = 'LOW' THEN 2
when CREDIT_RISK_RATING = 'MEDIUM' THEN 3
when CREDIT_RISK_RATING = 'HIGH' THEN 4
when CREDIT_RISK_RATING = 'CRITICAL' THEN 5
end as SQRR
,batch
,annualized_gpv_band
, gpv_dllr
,cb_dllr
,loss_dllr
,presale_dllr
from 
(select distinct unit_token, max(updated_at) max_date
from app_risk.app_risk_test.api_seller_intermediate_final
left join Regulator.raw_oltp.credit_risk_review_case_infos
on unit_token = user_token
--where batch = '2021Q1'
group by 1) seller
left join Regulator.raw_oltp.credit_risk_review_case_infos rating
on seller.unit_token = rating.user_token and seller.max_date = rating.updated_at
left join app_risk.app_risk_test.api_seller_intermediate_final trend
on seller.unit_token = trend.unit_token)
;

select 
batch
,annualized_gpv_band
,sum(gpv_dllr)
,sum(cb_dllr)
,sum(loss_dllr)
,sum(presale_dllr)
,count(distinct unit_token)
,sum(cb_dllr)/sum(gpv_dllr)*10000 as cb_rate
,sum(loss_dllr)/sum(gpv_dllr)*10000 as loss_rate
from app_risk.app_risk_test.api_seller_final_v2
group by 1,2
order by 1,2
;

select sqrr, avg(weekly_cnt)*52 from (
select 
 date_trunc('week', to_timestamp(CREATED_AT_millis/1000)) as payment_cohort_week
, sqrr
, count(distinct user_token) as weekly_cnt
from app_risk.app_risk_test.api_seller_final_v2 seller
left join creditactions.RAW_OLTP.CREDIT_RISK_RULE_RESULTS cr
on seller.unit_token = cr.user_token
where to_timestamp(CREATED_AT_millis/1000) between '2021-01-01' and '2021-03-31'
--and annualized_gpv_band in ('2.250k - 1M',
--'3.1M - 2M',
--'4.over 2M')
group by 1,2)
group by 1
order by 1
; 
 
-- SQRR
select sqrr, annualized_gpv_band, count(unit_token), sum (gpv_dllr), sum(cb_dllr), sum(loss_dllr), sum(presale_dllr)
from app_risk.app_risk_test.api_seller_final_v2
where batch = '2021Q1'
group by 1,2
order by 1,2
;
