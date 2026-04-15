CLASS lhc_Product DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Product RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Product RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Product.

    METHODS activateProduct FOR MODIFY
      IMPORTING keys FOR ACTION Product~activateProduct RESULT result.

    METHODS deactivateProduct FOR MODIFY
      IMPORTING keys FOR ACTION Product~deactivateProduct RESULT result.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Product~setInitialValues.

    METHODS validatePrice FOR VALIDATE ON SAVE
      IMPORTING keys FOR Product~validatePrice.

    METHODS validateStock FOR VALIDATE ON SAVE
      IMPORTING keys FOR Product~validateStock.

ENDCLASS.

CLASS lhc_Product IMPLEMENTATION.

  " ---------------------------------------------------------------------
  " 1. Instance Features (Dynamically enable/disable buttons)
  " ---------------------------------------------------------------------
  METHOD get_instance_features.
    " Read the current active status of the products
    READ ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( IsActive ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_products)
      FAILED failed.

    result = VALUE #( FOR ls_product IN lt_products (
      %tky = ls_product-%tky
      " If already active, disable Activate button. If inactive, disable Deactivate button.
      %action-activateProduct   = COND #( WHEN ls_product-IsActive = abap_true
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled )

      %action-deactivateProduct = COND #( WHEN ls_product-IsActive = abap_false OR ls_product-IsActive IS INITIAL
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled )
    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 2. Instance Authorizations (Placeholder for PFCG checks)
  " ---------------------------------------------------------------------
  METHOD get_instance_authorizations.
    " Basic implementation: Allow all operations for now.
    " In a real scenario, you would check AUTHORITY-CHECK here.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed
                      %action-activateProduct   = if_abap_behv=>auth-allowed
                      %action-deactivateProduct = if_abap_behv=>auth-allowed )
             TO result.
    ENDLOOP.
  ENDMETHOD.

 " ---------------------------------------------------------------------
  " Early Numbering (Crash-Proof Draft Version for Products)
  " ---------------------------------------------------------------------
  METHOD earlynumbering_create.
    DATA: lv_max_active TYPE zecom_products-product_id,
          lv_max_draft  TYPE zecom_prd_d-productid,  " <-- Notice: No underscore for the draft table field!
          lv_max_id     TYPE zecom_products-product_id.

    " 1. Fetch highest ID from the Active table
    SELECT SINGLE MAX( product_id ) FROM zecom_products INTO @lv_max_active.

    " 2. Fetch highest ID from the Draft table (prevents the duplicate key dump)
    SELECT SINGLE MAX( productid ) FROM zecom_prd_d INTO @lv_max_draft.

    " 3. Determine the absolute highest ID between the two
    IF lv_max_active > lv_max_draft.
      lv_max_id = lv_max_active.
    ELSE.
      lv_max_id = lv_max_draft.
    ENDIF.

    " 4. Assign new IDs
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).

      IF <ls_entity>-ProductId IS INITIAL.
        " Generate the next available number
        lv_max_id += 1.

        APPEND VALUE #( %cid      = <ls_entity>-%cid
                        %is_draft = <ls_entity>-%is_draft
                        ProductId = lv_max_id ) TO mapped-product.
      ELSE.
        " Pass through safely if provided manually by the draft framework
        APPEND VALUE #( %cid      = <ls_entity>-%cid
                        %is_draft = <ls_entity>-%is_draft
                        ProductId = <ls_entity>-ProductId ) TO mapped-product.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 4. Action: Activate Product
  " ---------------------------------------------------------------------
  METHOD activateProduct.
    " Modify the IsActive field to 'X'
    MODIFY ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        UPDATE FIELDS ( IsActive )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky IsActive = abap_true ) )
      FAILED failed
      REPORTED reported.

    " Read the updated data to return it to the UI
    READ ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_products).

    result = VALUE #( FOR ls_product IN lt_products (
                        %tky   = ls_product-%tky
                        %param = ls_product
                    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 5. Action: Deactivate Product
  " ---------------------------------------------------------------------
  METHOD deactivateProduct.
    " Modify the IsActive field to space (' ')
    MODIFY ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        UPDATE FIELDS ( IsActive )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky IsActive = abap_false ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_products).

    result = VALUE #( FOR ls_product IN lt_products (
                        %tky   = ls_product-%tky
                        %param = ls_product
                    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 6. Determination: Set Initial Values on Create
  " ---------------------------------------------------------------------
  METHOD setInitialValues.
    READ ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( IsActive Rating Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_products).

    " Set defaults if the fields are empty
    MODIFY ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        UPDATE FIELDS ( IsActive Rating Currency )
        WITH VALUE #( FOR ls_product IN lt_products
                      ( %tky     = ls_product-%tky
                        IsActive = COND #( WHEN ls_product-IsActive IS INITIAL THEN abap_true ELSE ls_product-IsActive )
                        Rating   = COND #( WHEN ls_product-Rating IS INITIAL THEN '0.00' ELSE ls_product-Rating )
                        Currency = COND #( WHEN ls_product-Currency IS INITIAL THEN 'USD' ELSE ls_product-Currency ) ) )
      REPORTED DATA(lt_update_reported).

    reported = CORRESPONDING #( DEEP lt_update_reported ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 7. Validation: Check Price > 0
  " ---------------------------------------------------------------------
  METHOD validatePrice.
    READ ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( Price ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_products).

    LOOP AT lt_products INTO DATA(ls_product).
      IF ls_product-Price <= 0.
        " Flag the record as failed to prevent saving
        APPEND VALUE #( %tky = ls_product-%tky ) TO failed-product.

        " Attach an error message to the specific Price field
        APPEND VALUE #( %tky = ls_product-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Price must be greater than zero' )
                        %element-price = if_abap_behv=>mk-on ) TO reported-product.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 8. Validation: Check Stock >= 0
  " ---------------------------------------------------------------------
  METHOD validateStock.
    READ ENTITIES OF zi_ecom_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( StockQty ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_products).

    LOOP AT lt_products INTO DATA(ls_product).
      IF ls_product-StockQty < 0.
        " Flag the record as failed
        APPEND VALUE #( %tky = ls_product-%tky ) TO failed-product.

        " Attach an error message to the specific Stock field
        APPEND VALUE #( %tky = ls_product-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Stock Quantity cannot be negative' )
                        %element-stockqty = if_abap_behv=>mk-on ) TO reported-product.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
