{% macro
    angstrom_bundle_tob_order_volume(raw_tx_input_hex)
%}




WITH 
    pratx_in AS (
        SELECT {{ raw_tx_input_hex }} AS parent_raw_tx_input_hex
    )
SELECT ab.* 
FROM pratx_in
CROSS JOIN LATERAL ({{angstrom_decoding_top_of_block_orders('pratx_in.parent_raw_tx_input_hex')}}) AS ab


{% endmacro %}
