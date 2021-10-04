create or replace table app_risk.app_risk_test.api_seller_batch as
select distinct unit_token
    ,case when payment_trx_recognized_date between '2019-01-01' and '2019-06-30' then '2019H1'
    when payment_trx_recognized_date between '2019-07-01' and '2019-12-31' then '2019H2'
    when payment_trx_recognized_date between '2020-01-01' and '2020-06-30' then '2020H1'
    when payment_trx_recognized_date between '2020-07-01' and '2020-12-31' then '2020H2'
    when payment_trx_recognized_date between '2021-01-01' and '2021-06-30' then '2021H1'
    else null end as batch
    from app_bi.pentagon.fact_payment_transactions fpt
    where currency_code = 'USD' and is_gpv = 1
    and payment_trx_recognized_date between '2019-01-01' and '2021-06-30'
    and product_name like '%API%'
;
  
create or replace table app_risk.app_risk_test.api_seller_api_gpv as
select 
fpt.unit_token
,sum(case when payment_trx_recognized_date between '2019-01-01' and '2019-06-30' then amount_base_unit_usd/100 else 0 end) as "2019H1_GPV_API"
,sum(case when payment_trx_recognized_date between '2019-07-01' and '2019-12-31' then amount_base_unit_usd/100 else 0 end) as "2019H2_GPV_API"
,sum(case when payment_trx_recognized_date between '2020-01-01' and '2020-06-30' then amount_base_unit_usd/100 else 0 end) as "2020H1_GPV_API"
,sum(case when payment_trx_recognized_date between '2020-07-01' and '2020-12-31' then amount_base_unit_usd/100 else 0 end) as "2020H2_GPV_API"
,sum(case when payment_trx_recognized_date between '2021-01-01' and '2021-06-30' then amount_base_unit_usd/100 else 0 end) as "2021H1_GPV_API"
,sum(case when payment_trx_recognized_date between '2021-01-01' and '2021-03-30' then amount_base_unit_usd/100 else 0 end) as "2021Q1_GPV_API"
from app_bi.pentagon.fact_payment_transactions fpt
    where currency_code = 'USD' and is_gpv = 1
    and payment_trx_recognized_date between '2019-01-01' and '2021-06-30'
    and product_name like '%API%'
GROUP BY 1
;
 
create or replace table app_risk.app_risk_test.api_seller_gpv as
select 
sds.user_token
,sum(case when payment_trx_recognized_date between '2019-01-01' and '2019-06-30' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2019H1_GPV"
,sum(case when payment_trx_recognized_date between '2019-07-01' and '2019-12-31' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2019H2_GPV"
,sum(case when payment_trx_recognized_date between '2020-01-01' and '2020-06-30' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2020H1_GPV"
,sum(case when payment_trx_recognized_date between '2020-07-01' and '2020-12-31' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2020H2_GPV"
,sum(case when payment_trx_recognized_date between '2021-01-01' and '2021-06-30' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2021H1_GPV"
,sum(case when payment_trx_recognized_date between '2021-01-01' and '2021-03-30' then GPV_PAYMENT_AMOUNT_BASE_UNIT_USD/100 else 0 end) as "2021Q1_GPV"
from app_bi.pentagon.aggregate_seller_daily_payment_summary sds
where sds.user_token in (select distinct unit_token 
                     from app_risk.app_risk_test.api_seller_batch)
                    group by 1
;

create or replace table app_risk.app_risk_test.api_seller_cb_loss as
select user_token
,sum(case when payment_created_at between '2019-01-01' and '2019-06-30' then chargeback_cents/100 else 0 end) as "2019H1_cb"
,sum(case when payment_created_at between '2019-07-01' and '2019-12-31' then chargeback_cents/100 else 0 end) as "2019H2_cb"
,sum(case when payment_created_at between '2020-01-01' and '2020-06-30' then chargeback_cents/100 else 0 end) as "2020H1_cb"
,sum(case when payment_created_at between '2020-07-01' and '2020-12-31' then chargeback_cents/100 else 0 end) as "2020H2_cb"
,sum(case when payment_created_at between '2021-01-01' and '2021-06-30' then chargeback_cents/100 else 0 end) as "2021H1_cb"
,sum(case when payment_created_at between '2021-01-01' and '2021-03-31' then chargeback_cents/100 else 0 end) as "2021Q1_cb"
,sum(case when payment_created_at between '2019-01-01' and '2019-06-30' then loss_cents/100 else 0 end) as "2019H1_loss"
,sum(case when payment_created_at between '2019-07-01' and '2019-12-31' then loss_cents/100 else 0 end) as "2019H2_loss"
,sum(case when payment_created_at between '2020-01-01' and '2020-06-30' then loss_cents/100 else 0 end) as "2020H1_loss"
,sum(case when payment_created_at between '2020-07-01' and '2020-12-31' then loss_cents/100 else 0 end) as "2020H2_loss"
,sum(case when payment_created_at between '2021-01-01' and '2021-06-30' then loss_cents/100 else 0 end) as "2021H1_loss"
,sum(case when payment_created_at between '2021-01-01' and '2021-03-31' then loss_cents/100 else 0 end) as "2021Q1_loss"
from app_risk.app_risk.chargebacks 
where user_token in (select distinct unit_token 
                     from app_risk.app_risk_test.api_seller_batch)
                    group by 1
;

create or replace table app_risk.app_risk_test.api_seller_trend as
select 
batch
,batch.unit_token
,case when batch = '2019H1' then "2019H1_GPV"
when batch = '2019H2' then "2019H2_GPV"
when batch = '2020H1' then "2020H1_GPV"
when batch = '2020H2' then "2020H2_GPV"
when batch = '2021H1' then "2021H1_GPV"
end as gpv_dllr
,case when gpv_dllr*2 < 100000 then '0.<100k'
when gpv_dllr*2 < 250000 then '1.100k - 250k'
when gpv_dllr*2 < 1000000 then '2.250k - 1M'
when gpv_dllr*2 < 2000000 then '3.1M - 2M'
when gpv_dllr*2 >= 2000000 then '4.over 2M'
end as annualized_gpv_band
,case when batch = '2019H1' then "2019H1_GPV_API"
when batch = '2019H2' then "2019H2_GPV_API"
when batch = '2020H1' then "2020H1_GPV_API"
when batch = '2020H2' then "2020H2_GPV_API"
when batch = '2021H1' then "2021H1_GPV_API"
end as gpv_dllr_api
,case when batch = '2019H1' then "2019H1_CB"
when batch = '2019H2' then "2019H2_CB"
when batch = '2020H1' then "2020H1_CB"
when batch = '2020H2' then "2020H2_CB"
when batch = '2021H1' then "2021H1_CB"
end as cb_dllr
,case when batch = '2019H1' then "2019H1_LOSS"
when batch = '2019H2' then "2019H2_LOSS"
when batch = '2020H1' then "2020H1_LOSS"
when batch = '2020H2' then "2020H2_LOSS"
when batch = '2021H1' then "2021H1_LOSS"
end as loss_dllr
,case when batch = '2021H1' then "2021Q1_GPV" else null end as "2021Q1_GPV"
,case when batch = '2021H1' then "2021Q1_CB" else null end as "2021Q1_CB"
,case when batch = '2021H1' then "2021Q1_LOSS" else null end as "2021Q1_LOSS"
,case when gpv_dllr_api/gpv_dllr > 0.5 then 1 else 0 end as api_gt_50_flag
from app_risk.app_risk_test.api_seller_batch batch
left join app_risk.app_risk_test.api_seller_gpv gpv
on batch.unit_token = gpv.user_token
left join app_risk.app_risk_test.api_seller_cb_loss cb
on batch.unit_token = cb.user_token
left join app_risk.app_risk_test.api_seller_api_gpv api_gpv
on batch.unit_token = api_gpv.unit_token
;

select
batch
,api_gt_50_flag
,count(unit_token) as seller_cnt
,sum(gpv_dllr) as gpv_dllr
,sum(cb_dllr) as cb_dllr
,sum(loss_dllr) as loss_dllr
,sum("2021Q1_GPV") as "21H1_seller_21Q1_gpv"
,sum("2021Q1_CB") as "21H1_seller_21Q1_cb"
,sum("2021Q1_LOSS") as "21H1_seller_21Q1_loss"
from app_risk.app_risk_test.api_seller_trend
--where gpv_dllr > 1000000
group by 1,2
order by 1,2
;

-- switch code to 2021Q1 metrics for 2021H1 seller 2021Q1$
select 
batch
,annualized_gpv_band
,sum(gpv_dllr)
,sum(cb_dllr)
,sum(loss_dllr)
,count(unit_token)
--,sum("2021Q1_GPV")
--,sum("2021Q1_CB")
--,sum("2021Q1_LOSS")
--,count(unit_token)
from app_risk.app_risk_test.api_seller_trend
--where batch = '2021H1'
--and "2021Q1_GPV" is not null
group by 1,2
order by 1,2
;
