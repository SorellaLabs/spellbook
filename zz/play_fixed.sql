with
    dexs as (
        with
            tx_data_cte as (
                select
                    block_number,
                    block_time,
                    tx_hash,
                    tx_index,
                    angstrom_address,
                    tx_data
                from
                    (
                        select
                            t.block_number as block_number,
                            t.block_time as block_time,
                            t.hash as tx_hash,
                            t.index as tx_index,
                            t.to as angstrom_address,
                            t.data as tx_data
                        from "delta_prod"."ethereum"."transactions" as t
                        where
                            t.to = 0xb9c4ce42c2e29132e207d29af6a7719065ca6aec
                            and varbinary_substring(t.data, 1, 4) = 0x09c5eabe
                            and t.hash
                            = 0x47aefe13a19c8036c0985b59090a34adffcad108630a86aae298954554394d10
                    )
            ),
            -- First, decode the TOB orders from the transaction data
            tob_orders_decoded as (
                select
                    t.*,
                    ab.use_internal,
                    ab.quantity_in,
                    ab.quantity_out,
                    ab.max_gas_asset_0,
                    ab.gas_used_asset_0,
                    ab.pairs_index,
                    ab.zero_for_1,
                    ab.recipient,
                    ab.idx
                from tx_data_cte t
                cross join lateral (
                    -- Decode TOB orders
                    with
                        trimmed_input as (
                            select
                                1 as next_offset,
                                varbinary_substring(t.tx_data, 69) as next_buf
                        ),
                        -- Skip assets
                        step0 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from trimmed_input
                            )
                        ),
                        -- Skip pairs
                        step1 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from step0
                            )
                        ),
                        -- Skip pool updates
                        step2 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from step1
                            )
                        ),
                        -- Get TOB orders buffer
                        step3 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from step2
                            )
                        ),
                        vec_pade as (
                            select buf from step3
                        )
                    select *
                    from (
                        with recursive
                            decode_tob_order(
                                buf,
                                pointer,
                                idx,
                                use_internal,
                                quantity_in,
                                quantity_out,
                                max_gas_asset_0,
                                gas_used_asset_0,
                                pairs_index,
                                zero_for_1,
                                recipient
                            ) as (
                                select
                                    varbinary_substring(buf, 4, varbinary_length(buf) - 3),
                                    4,
                                    0,
                                    cast(null as boolean),
                                    cast(null as uint256),
                                    cast(null as uint256),
                                    cast(null as uint256),
                                    cast(null as uint256),
                                    cast(null as bigint),
                                    cast(null as boolean),
                                    cast(null as varbinary)
                                from vec_pade

                                union all

                                select
                                    buf,
                                    pointer,
                                    idx,
                                    use_internal,
                                    quantity_in,
                                    quantity_out,
                                    max_gas_asset_0,
                                    gas_used_asset_0,
                                    pairs_index,
                                    zero_for_1,
                                    recipient
                                from (
                                    with
                                        trimmed_as_fields as (
                                            select
                                                idx + 1 as idx,
                                                array[
                                                    bitwise_and(bitwise_right_shift(varbinary_to_integer(varbinary_substring(buf, 1, 1)), 3), 1),
                                                    bitwise_and(bitwise_right_shift(varbinary_to_integer(varbinary_substring(buf, 1, 1)), 2), 1),
                                                    bitwise_and(bitwise_right_shift(varbinary_to_integer(varbinary_substring(buf, 1, 1)), 1), 1),
                                                    bitwise_and(varbinary_to_integer(varbinary_substring(buf, 1, 1)), 1)
                                                ] as bitmap,
                                                buf,
                                                2 as pointer
                                            from decode_tob_order
                                        ),
                                        use_internal_field as (
                                            select
                                                idx,
                                                if(bitmap[4] = 1, true, false) as use_internal,
                                                bitmap,
                                                pointer,
                                                buf
                                            from trimmed_as_fields
                                        ),
                                        quantity_in_field as (
                                            select
                                                idx,
                                                use_internal,
                                                varbinary_to_uint256(varbinary_substring(buf, pointer, 16)) as quantity_in,
                                                bitmap,
                                                pointer + 16 as pointer,
                                                buf
                                            from use_internal_field
                                        ),
                                        quantity_out_field as (
                                            select
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                varbinary_to_uint256(varbinary_substring(buf, pointer, 16)) as quantity_out,
                                                bitmap,
                                                pointer + 16 as pointer,
                                                buf
                                            from quantity_in_field
                                        ),
                                        max_gas_asset_0_field as (
                                            select
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                quantity_out,
                                                varbinary_to_uint256(varbinary_substring(buf, pointer, 16)) as max_gas_asset_0,
                                                bitmap,
                                                pointer + 16 as pointer,
                                                buf
                                            from quantity_out_field
                                        ),
                                        gas_used_asset_0_field as (
                                            select
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                quantity_out,
                                                max_gas_asset_0,
                                                varbinary_to_uint256(varbinary_substring(buf, pointer, 16)) as gas_used_asset_0,
                                                bitmap,
                                                pointer + 16 as pointer,
                                                buf
                                            from max_gas_asset_0_field
                                        ),
                                        pairs_index_field as (
                                            select
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                quantity_out,
                                                max_gas_asset_0,
                                                gas_used_asset_0,
                                                varbinary_to_bigint(varbinary_substring(buf, pointer, 2)) as pairs_index,
                                                bitmap,
                                                pointer + 2 as pointer,
                                                buf
                                            from gas_used_asset_0_field
                                        ),
                                        zero_for_1_field as (
                                            select
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                quantity_out,
                                                max_gas_asset_0,
                                                gas_used_asset_0,
                                                pairs_index,
                                                if(bitmap[3] = 1, true, false) as zero_for_1,
                                                bitmap,
                                                pointer,
                                                buf
                                            from pairs_index_field
                                        ),
                                        recipient_field as (
                                            select
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                quantity_out,
                                                max_gas_asset_0,
                                                gas_used_asset_0,
                                                pairs_index,
                                                zero_for_1,
                                                if(bitmap[2] = 1, varbinary_substring(buf, pointer, 20), null) as recipient,
                                                bitmap,
                                                if(bitmap[2] = 1, pointer + 20, pointer) as pointer,
                                                buf
                                            from zero_for_1_field
                                        ),
                                        all_fields_collapsed as (
                                            select
                                                buf,
                                                pointer,
                                                idx,
                                                use_internal,
                                                quantity_in,
                                                quantity_out,
                                                max_gas_asset_0,
                                                gas_used_asset_0,
                                                pairs_index,
                                                zero_for_1,
                                                recipient
                                            from recipient_field
                                        )
                                    select
                                        varbinary_substring(buf, pointer) as buf,
                                        pointer,
                                        idx,
                                        use_internal,
                                        quantity_in,
                                        quantity_out,
                                        max_gas_asset_0,
                                        gas_used_asset_0,
                                        pairs_index,
                                        zero_for_1,
                                        recipient
                                    from all_fields_collapsed
                                    where varbinary_length(buf) != 0
                                )
                            )
                        select *
                        from decode_tob_order
                        where idx > 0
                    ) 
                ) as ab
            ),
            -- Now decode assets
            assets_decoded as (
                select
                    t.tx_hash,
                    assets.*
                from tx_data_cte t
                cross join lateral (
                    with
                        trimmed_input as (
                            select
                                1 as next_offset,
                                varbinary_substring(t.tx_data, 69) as next_buf
                        ),
                        -- Get assets buffer
                        step0 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from trimmed_input
                            )
                        ),
                        vec_pade as (
                            select buf from step0
                        )
                    select *
                    from (
                        with recursive
                            decode_asset(buf, len, idx, addr, save, take, settle) as (
                                select
                                    varbinary_substring(buf, 4, varbinary_length(buf) - 3),
                                    varbinary_to_integer(varbinary_substring(buf, 1, 3)) / 68 as len,
                                    0 as idx,
                                    cast(null as varbinary) as addr,
                                    cast(0 as uint256) as save,
                                    cast(0 as uint256) as take,
                                    cast(0 as uint256) as settle
                                from vec_pade

                                union all

                                select
                                    varbinary_substring(buf, 69, varbinary_length(buf) - 68) as enc,
                                    len,
                                    idx + 1 as new_idx,
                                    varbinary_substring(buf, 1, 20) as addr,
                                    varbinary_to_uint256(varbinary_substring(buf, 21, 16)) as save,
                                    varbinary_to_uint256(varbinary_substring(buf, 37, 16)) as take,
                                    varbinary_to_uint256(varbinary_substring(buf, 53, 16)) as settle
                                from decode_asset
                                where idx < len
                            )
                        select
                            idx as bundle_idx,
                            addr as token_address
                        from decode_asset
                        where idx > 0
                    )
                ) as assets
            ),
            -- Now decode pairs
            pairs_decoded as (
                select
                    t.tx_hash,
                    pairs.*
                from tx_data_cte t
                cross join lateral (
                    with
                        trimmed_input as (
                            select
                                1 as next_offset,
                                varbinary_substring(t.tx_data, 69) as next_buf
                        ),
                        -- Skip assets
                        step0 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from trimmed_input
                            )
                        ),
                        -- Get pairs buffer
                        step1 as (
                            select 
                                len + 3 + offset as next_offset,
                                varbinary_substring(next_buf, offset, len + 3) as buf,
                                next_buf
                            from (
                                select
                                    next_offset as offset,
                                    varbinary_to_integer(varbinary_substring(next_buf, next_offset, 3)) as len,
                                    next_buf
                                from step0
                            )
                        ),
                        vec_pade as (
                            select buf from step1
                        )
                    select *
                    from (
                        with recursive
                            decode_pair(buf, len, idx, index0, index1, store_index, price_1over0) as (
                                select
                                    varbinary_substring(buf, 4, varbinary_length(buf) - 3),
                                    varbinary_to_integer(varbinary_substring(buf, 1, 3)) / 38 as len,
                                    0 as idx,
                                    0 as index0,
                                    0 as index1,
                                    0 as store_index,
                                    cast(0 as uint256) as price_1over0
                                from vec_pade

                                union all

                                select
                                    varbinary_substring(buf, 39, varbinary_length(buf) - 38) as enc,
                                    len,
                                    idx + 1 as new_idx,
                                    varbinary_to_integer(varbinary_substring(buf, 1, 2)) as index0,
                                    varbinary_to_integer(varbinary_substring(buf, 3, 2)) as index1,
                                    varbinary_to_integer(varbinary_substring(buf, 5, 2)) as store_index,
                                    varbinary_to_uint256(varbinary_substring(buf, 7, 32)) as price_1over0
                                from decode_pair
                                where idx < len
                            )
                        select
                            idx as bundle_idx,
                            index0,
                            index1,
                            price_1over0
                        from decode_pair
                        where idx > 0
                    )
                ) as pairs
            ),
            -- Now join everything together
            tob_orders as (
                select
                    t.block_number,
                    t.block_time,
                    t.quantity_in as token_bought_amount_raw,
                    t.quantity_out as token_sold_amount_raw,
                    case 
                        when t.zero_for_1 then a_in.token_address
                        else a_out.token_address
                    end as token_bought_address,
                    case 
                        when t.zero_for_1 then a_out.token_address
                        else a_in.token_address
                    end as token_sold_address,
                    t.recipient as taker,
                    t.angstrom_address as maker,
                    t.angstrom_address as project_contract_address,
                    t.tx_hash,
                    t.tx_data,
                    row_number() over (partition by t.tx_hash order by t.idx) as evt_index
                from tob_orders_decoded t
                inner join pairs_decoded p on t.tx_hash = p.tx_hash and t.pairs_index = p.bundle_idx
                inner join assets_decoded a_in on t.tx_hash = a_in.tx_hash and p.index0 = a_in.bundle_idx
                inner join assets_decoded a_out on t.tx_hash = a_out.tx_hash and p.index1 = a_out.bundle_idx
            )
        select * from tob_orders
    )
select * from dexs