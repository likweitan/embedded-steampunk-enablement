CLASS lhc_online_shop DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR online_shop RESULT result.

    METHODS create_pr FOR MODIFY
      IMPORTING keys FOR ACTION online_shop~create_pr.

    METHODS update_inforecord FOR MODIFY
      IMPORTING keys FOR ACTION online_shop~update_inforecord.

    METHODS calculate_order_id FOR DETERMINE ON MODIFY
      IMPORTING keys FOR online_shop~calculate_order_id.

    METHODS set_inforecord FOR MODIFY
      IMPORTING keys FOR ACTION online_shop~set_inforecord.


ENDCLASS.

CLASS lhc_online_shop IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD create_pr.
*  if a new package is ordered, trigger a new purchase requisition
    DATA(key) = keys[ 1 ].
    SELECT SINGLE * FROM zc_prepackageditems WHERE pkgid = @key-%param-packageid INTO @DATA(ls_prepitem).

    TRY.
        MODIFY ENTITIES OF i_purchaserequisitiontp
        ENTITY purchaserequisition
        CREATE FIELDS ( purchaserequisitiontype )
        WITH VALUE #(  ( %cid                    = 'My%CID_1'
                         purchaserequisitiontype = 'NB' ) )
        CREATE BY \_purchaserequisitionitem
        FIELDS ( plant
                 purchaserequisitionitemtext
                 accountassignmentcategory
                 requestedquantity
                 baseunit
                 purchaserequisitionprice
                 purreqnitemcurrency
                 materialgroup
                 purchasinggroup
                 purchasingorganization )
        WITH VALUE #( ( %cid_ref = 'My%CID_1'
                        %target  = VALUE #( ( %cid                            = 'My%ItemCID_1'
                                             plant                           = ls_prepitem-plant
                                             purchaserequisitionitemtext     = ls_prepitem-purchaserequisitionitemtext
                                             accountassignmentcategory       = ls_prepitem-accountassignmentcategory
                                             requestedquantity               = ls_prepitem-requestedquantity
                                             baseunit                        = ls_prepitem-baseunit
                                             purchaserequisitionprice        = ls_prepitem-purchaserequisitionprice
                                             purreqnitemcurrency             = ls_prepitem-purreqnitemcurrency
                                             materialgroup                   = ls_prepitem-materialgroup
                                             purchasinggroup                 = ls_prepitem-purchasinggroup
                                             purchasingorganization          = ls_prepitem-purchasingorganization ) ) ) )
        ENTITY purchaserequisitionitem
        CREATE BY \_purchasereqnacctassgmt
        FIELDS ( costcenter
                 glaccount
                 quantity
                 baseunit )
        WITH VALUE #( ( %cid_ref = 'My%ItemCID_1'
                        %target  = VALUE #( ( %cid        = 'My%CC_1'
                                              costcenter   = key-%param-costcenter " e.g. 'JMW-COST'
                                              glaccount    = '10010000' ) ) ) )
        CREATE BY \_purchasereqnitemtext
        FIELDS ( plainlongtext )
        WITH VALUE #( ( %cid_ref = 'My%ItemCID_1'
                        %target  = VALUE #( (
                                            %cid           = 'My%CCT_1'
                                            textobjecttype = 'B01'
                                            language       = 'E'
                                            plainlongtext  = 'item text created from PAAS API LW1 - Workshop prep.'
                                          ) (
                                            %cid           = 'My%CCT_2'
                                            textobjecttype = 'B02'
                                            language       = 'E'
                                            plainlongtext  = 'item2 text created from PAAS API LW1'
                                          ) )
                )   )
        REPORTED DATA(ls_pr_reported)
        MAPPED DATA(ls_pr_mapped)
        FAILED DATA(ls_pr_failed).

        zbp_r_online_shop_lw01=>cv_pr_mapped = ls_pr_mapped.
      CATCH cx_root INTO DATA(exception).
        " Handle exception
    ENDTRY.

  ENDMETHOD.

  METHOD calculate_order_id.

    DATA:
      online_shops TYPE TABLE FOR UPDATE zr_online_shop_lw01,
      online_shop  TYPE STRUCTURE FOR UPDATE zr_online_shop_lw01.

    READ ENTITIES OF zr_online_shop_lw01 IN LOCAL MODE
       ENTITY online_shop
        ALL FIELDS
          WITH CORRESPONDING #( keys )
          RESULT DATA(lt_online_shop_result)
      FAILED    DATA(lt_failed)
      REPORTED  DATA(lt_reported).
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_online_shop_result INTO DATA(online_shop_read).
      online_shop               = CORRESPONDING #( online_shop_read ).
      IF online_shop-order_id IS INITIAL.
        TRY.
            CALL METHOD cl_numberrange_runtime=>number_get
              EXPORTING
                nr_range_nr = '01'
                object      = 'ZOSOID_LW1'
              IMPORTING
                number      = DATA(order_id)
                returncode  = DATA(rcode).
          CATCH cx_nr_object_not_found.
          CATCH cx_number_ranges.
        ENDTRY.
        online_shop-order_id = CONV int4( order_id ).
        online_shop-creationdate  = today.
        IF online_shop-deliverydate IS INITIAL.
          online_shop-deliverydate  = today + 10.
        ENDIF.

        APPEND online_shop TO online_shops.
      ENDIF.
    ENDLOOP.
    MODIFY ENTITIES OF zr_online_shop_lw01 IN LOCAL MODE
    ENTITY online_shop UPDATE SET FIELDS WITH online_shops
    MAPPED   DATA(ls_mapped_modify)
    FAILED   DATA(lt_failed_modify)
    REPORTED DATA(lt_reported_modify).

    DATA: lt_create_pr_imp TYPE TABLE FOR ACTION IMPORT  zr_online_shop_lw01~create_pr,
          ls_create_pr_imp LIKE LINE OF lt_create_pr_imp.


    LOOP AT online_shops INTO DATA(online_shop_result).
      ls_create_pr_imp-order_uuid = online_shop_result-order_uuid.
      ls_create_pr_imp-%param = CORRESPONDING #( online_shop_result ).
      APPEND ls_create_pr_imp TO lt_create_pr_imp.
    ENDLOOP.

    " if a new online order is created, trigger a new purchase requisition
    IF lt_failed_modify IS INITIAL.
      MODIFY ENTITIES OF zr_online_shop_lw01 IN LOCAL MODE
      ENTITY online_shop EXECUTE create_pr FROM CORRESPONDING #( lt_create_pr_imp )
      FAILED DATA(lt_pr_failed)
      REPORTED DATA(lt_pr_reported).
    ENDIF.

  ENDMETHOD.

  METHOD update_inforecord.
    SELECT SINGLE * FROM i_purchasinginforecordtp  WHERE purchasinginforecord = '5500000219' INTO @DATA(ls_data).

* Update an existing info record
    MODIFY ENTITIES OF i_purchasinginforecordtp
           ENTITY purchasinginforecord
           UPDATE SET FIELDS WITH
           VALUE #( ( %key-purchasinginforecord = '5500000219'
                       supplier                 = ls_data-supplier
                       materialgroup            = ls_data-materialgroup
                       suppliermaterialgroup    = ls_data-suppliermaterialgroup
                       nodaysreminder1          = '12'
                       purchasinginforecorddesc = 'noDays remainder updated'
                  ) )
             FAILED   DATA(ls_failed_update)
             REPORTED DATA(ls_reported_update)
             MAPPED   DATA(ls_mapped_update).
  ENDMETHOD.

  METHOD set_inforecord.

  ENDMETHOD.

ENDCLASS.

CLASS lsc_zr_online_shop_lw01 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zr_online_shop_lw01 IMPLEMENTATION.

  METHOD save_modified.
    DATA : lt_online_shop_as TYPE STANDARD TABLE OF zshop_as_lw01,
           ls_online_shop_as TYPE                   zshop_as_lw01.
    IF zbp_r_online_shop_lw01=>cv_pr_mapped-purchaserequisition IS NOT INITIAL.
      LOOP AT zbp_r_online_shop_lw01=>cv_pr_mapped-purchaserequisition ASSIGNING FIELD-SYMBOL(<fs_pr_mapped>).
        CONVERT KEY OF i_purchaserequisitiontp FROM <fs_pr_mapped>-%pid TO DATA(ls_pr_key).
        <fs_pr_mapped>-purchaserequisition = ls_pr_key-purchaserequisition.
      ENDLOOP.
    ENDIF.

    IF create-online_shop IS NOT INITIAL.
      " Creates internal table with instance data
      lt_online_shop_as = CORRESPONDING #( create-online_shop ).
      lt_online_shop_as[ 1 ]-purchasereqn =  ls_pr_key-purchaserequisition .
      INSERT zshop_as_lw01 FROM TABLE @lt_online_shop_as.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
