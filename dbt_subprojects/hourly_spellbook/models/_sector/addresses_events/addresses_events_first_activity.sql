{{ config
(
    alias = 'first_activity',
    schema = 'addresses_events',
    post_hook='{{ expose_spells(\'["arbitrum", "avalanche_c", "bnb", "ethereum", "fantom", "gnosis", "optimism", "polygon", "celo", "zksync", "zora", "base", "scroll", "sei", "mantle", "blast", "ronin", "nova", "abstract", "apechain", "berachain", "katana"]\',
                                    "sector",
                                    "addresses_events",
                                    \'["Henrystats", "hildobby", "0xr3x"]\') }}'
)
}}

{% set addresses_events_models = [
  ref('addresses_events_arbitrum_first_activity')
, ref('addresses_events_avalanche_c_first_activity')
, ref('addresses_events_bnb_first_activity')
, ref('addresses_events_ethereum_first_activity')
, ref('addresses_events_fantom_first_activity')
, ref('addresses_events_gnosis_first_activity')
, ref('addresses_events_optimism_first_activity')
, ref('addresses_events_polygon_first_activity')
, ref('addresses_events_celo_first_activity')
, ref('addresses_events_zksync_first_activity')
, ref('addresses_events_zora_first_activity')
, ref('addresses_events_base_first_activity')
, ref('addresses_events_scroll_first_activity')
, ref('addresses_events_zkevm_first_activity')
, ref('addresses_events_linea_first_activity')
, ref('addresses_events_sei_first_activity')
, ref('addresses_events_mantle_first_activity')
, ref('addresses_events_blast_first_activity')
, ref('addresses_events_ronin_first_activity')
, ref('addresses_events_nova_first_activity')
, ref('addresses_events_abstract_first_activity')
, ref('addresses_events_apechain_first_activity')
, ref('addresses_events_berachain_first_activity')
, ref('addresses_events_katana_first_activity')
] %}

SELECT *
FROM (
    {% for addresses_events_model in addresses_events_models %}
    SELECT
      blockchain
    , address
    , first_activity_to
    , first_block_time
    , first_block_number
    , first_tx_hash
    , first_function
    FROM {{ addresses_events_model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)