CLASS zcl_change_matdesc_lw01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_change_matdesc_lw01 IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA product_detail TYPE TABLE FOR CREATE i_producttp_2.

    product_detail = VALUE #( (
     %cid = 'product1'
     product = 'CUSTOM_PRODUCT'
     %control-product = if_abap_behv=>mk-on
     producttype = 'FERT'
     %control-producttype = if_abap_behv=>mk-on
     baseunit = 'EA'
     %control-baseunit = if_abap_behv=>mk-on
     industrysector = 'M'
     %control-industrysector = if_abap_behv=>mk-on
     ) ).

    MODIFY ENTITIES OF i_producttp_2
      ENTITY productdescription
      UPDATE FIELDS ( productdescription )
      WITH VALUE #( ( %key-product = 'TEST_PRODUCT'
      %key-language = 'D'
      productdescription = 'Description updated' ) )

    REPORTED DATA(reported)
     FAILED DATA(failed).

    COMMIT ENTITIES
      RESPONSE OF i_producttp_2
      FAILED DATA(failed_commit)
      REPORTED DATA(reported_commit).
  ENDMETHOD.
ENDCLASS.
