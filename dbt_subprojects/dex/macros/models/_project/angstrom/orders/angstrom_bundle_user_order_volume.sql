{% macro
    angstrom_bundle_user_order_volume(        
        angstrom_contract_addr, 
        blockchain, 
        raw_tx_input_hex, 
        fetched_bn
    )
%}



WITH
    user_orders AS (
        SELECT
            seed.txi, 
            user_vs.*       
        FROM (
            SELECT t.tx_data AS txi
        ) AS seed
        CROSS JOIN LATERAL (
            SELECT 
                ab.*,
                if(ab.order_quantities_kind = 'Exact', ab.order_quantities_exact_quantity, ab.order_quantities_partial_filled_quantity) AS fill_amount,
                asts.*
            FROM ({{angstrom_decoding_user_orders('seed.txi')}}) AS ab
            CROSS JOIN LATERAL ({{ angstrom_bundle_indexes_to_assets('seed.txi', 'ab.pair_index', 'ab.zero_for_one') }}) AS asts
        ) AS user_vs
    ),
    orders_with_assets AS (
        SELECT
            u.*,
            a.*
        FROM user_orders AS u
        CROSS JOIN LATERAL ({{ angstrom_pool_fees(angstrom_contract_addr, blockchain, 'u.asset_in', 'u.asset_out', fetched_bn) }}) AS f
        CROSS JOIN LATERAL ({{ angstrom_user_order_fill_amount('u.zero_for_one', 'u.exact_in', 'u.fill_amount', 'u.extra_fee_asset0', 'f.bundle_fee', 'u.price_1over0') }}) AS a
    )
SELECT
    *
FROM orders_with_assets





{% endmacro %}
