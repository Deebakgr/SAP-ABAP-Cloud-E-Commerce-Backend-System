
CLASS lhc_Orders DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Orders RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Orders RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Orders.

    METHODS cancelOrder FOR MODIFY
      IMPORTING keys FOR ACTION Orders~cancelOrder RESULT result.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Orders~setInitialValues.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Orders~calculateTotalPrice.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Orders~validateQuantity.
    METHODS confirmOrder FOR MODIFY
      IMPORTING keys FOR ACTION Orders~confirmOrder RESULT result.

    METHODS setPending FOR MODIFY
      IMPORTING keys FOR ACTION Orders~setPending RESULT result.

    METHODS shipOrder FOR MODIFY
      IMPORTING keys FOR ACTION Orders~shipOrder RESULT result.

ENDCLASS.

CLASS lhc_Orders IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders)
      FAILED failed.

    result = VALUE #( FOR ls_order IN lt_orders (
      %tky = ls_order-%tky

      %action-cancelOrder  = COND #( WHEN ls_order-Status = 'CANCELLED' OR ls_order-Status = 'SHIPPED' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      %action-confirmOrder = COND #( WHEN ls_order-Status = 'CANCELLED' OR ls_order-Status = 'SHIPPED' OR ls_order-Status = 'CONFIRMED' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      %action-shipOrder    = COND #( WHEN ls_order-Status = 'CANCELLED' OR ls_order-Status = 'SHIPPED' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      %action-setPending   = COND #( WHEN ls_order-Status = 'CANCELLED' OR ls_order-Status = 'SHIPPED' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
    ) ).
  ENDMETHOD.
  " ---------------------------------------------------------------------
  " 2. Instance Authorizations (Placeholder)
  " ---------------------------------------------------------------------
  METHOD get_instance_authorizations.
    " Allow operations for now
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed
                      %action-cancelOrder = if_abap_behv=>auth-allowed )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " Early Numbering (Crash-Proof Draft Version for Orders)
  " ---------------------------------------------------------------------
  METHOD earlynumbering_create.
    DATA: lv_max_active TYPE zecom_orders-order_id,
          lv_max_draft  TYPE zecom_ord_d-orderid,  " <-- Notice: No underscore for the draft table field!
          lv_max_id     TYPE zecom_orders-order_id.

    " 1. Fetch highest ID from the Active table
    SELECT SINGLE MAX( order_id ) FROM zecom_orders INTO @lv_max_active.

    " 2. Fetch highest ID from the Draft table (prevents the duplicate key dump)
    SELECT SINGLE MAX( orderid ) FROM zecom_ord_d INTO @lv_max_draft.

    " 3. Determine the absolute highest ID between the two
    IF lv_max_active > lv_max_draft.
      lv_max_id = lv_max_active.
    ELSE.
      lv_max_id = lv_max_draft.
    ENDIF.

    " 4. Assign new IDs
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).

      IF <ls_entity>-OrderId IS INITIAL.
        " Generate the next available number
        lv_max_id += 1.

        APPEND VALUE #( %cid      = <ls_entity>-%cid
                        %is_draft = <ls_entity>-%is_draft
                        OrderId   = lv_max_id ) TO mapped-orders.
      ELSE.
        " Pass through safely if provided manually by the draft framework
        APPEND VALUE #( %cid      = <ls_entity>-%cid
                        %is_draft = <ls_entity>-%is_draft
                        OrderId   = <ls_entity>-OrderId ) TO mapped-orders.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 4. Action: Cancel Order
  " ---------------------------------------------------------------------
  METHOD cancelOrder.
    " Set Status to 'CANCELLED'
    MODIFY ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'CANCELLED' ) )
      FAILED failed
      REPORTED reported.

    " Read and return the updated data to refresh the UI
    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    result = VALUE #( FOR ls_order IN lt_orders (
                        %tky   = ls_order-%tky
                        %param = ls_order
                    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 5. Determination: Set Initial Values
  " ---------------------------------------------------------------------
  METHOD setInitialValues.
    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        FIELDS ( Status OrderDate OrderTime ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    " Set default values for new orders
    MODIFY ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        UPDATE FIELDS ( Status OrderDate OrderTime )
        WITH VALUE #( FOR ls_order IN lt_orders
                      ( %tky      = ls_order-%tky
                        Status    = COND #( WHEN ls_order-Status IS INITIAL THEN 'NEW' ELSE ls_order-Status )
                        OrderDate = COND #( WHEN ls_order-OrderDate IS INITIAL THEN lv_date ELSE ls_order-OrderDate )
                        OrderTime = COND #( WHEN ls_order-OrderTime IS INITIAL THEN lv_time ELSE ls_order-OrderTime ) ) )
      REPORTED DATA(lt_update_reported).

    reported = CORRESPONDING #( DEEP lt_update_reported ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 6. Determination: Calculate Total Price
  " ---------------------------------------------------------------------
  METHOD calculateTotalPrice.
    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        FIELDS ( Quantity UnitPrice DiscountPct ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_order>).
      " Formula: (Quantity * UnitPrice) - Discount
      DATA(lv_base_price) = <ls_order>-Quantity * <ls_order>-UnitPrice.
      DATA(lv_discount)   = lv_base_price * ( <ls_order>-DiscountPct / 100 ).
      DATA(lv_total)      = lv_base_price - lv_discount.

      MODIFY ENTITIES OF zi_ecom_orders IN LOCAL MODE
        ENTITY Orders
          UPDATE FIELDS ( TotalPrice )
          WITH VALUE #( ( %tky = <ls_order>-%tky TotalPrice = lv_total ) ).
    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 7. Validation: Check Quantity > 0
  " ---------------------------------------------------------------------
  METHOD validateQuantity.
    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE
      ENTITY Orders
        FIELDS ( Quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    LOOP AT lt_orders INTO DATA(ls_order).
      IF ls_order-Quantity <= 0.
        APPEND VALUE #( %tky = ls_order-%tky ) TO failed-orders.

        APPEND VALUE #( %tky = ls_order-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Quantity must be at least 1' )
                        %element-quantity = if_abap_behv=>mk-on ) TO reported-orders.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD confirmOrder.
    MODIFY ENTITIES OF zi_ecom_orders IN LOCAL MODE ENTITY Orders
      UPDATE FIELDS ( Status ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'CONFIRMED' ) ).

    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE ENTITY Orders ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_orders).
    result = VALUE #( FOR ls_order IN lt_orders ( %tky = ls_order-%tky %param = ls_order ) ).
  ENDMETHOD.

  METHOD setPending.
    MODIFY ENTITIES OF zi_ecom_orders IN LOCAL MODE ENTITY Orders
      UPDATE FIELDS ( Status ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'PENDING' ) ).

    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE ENTITY Orders ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_orders).
    result = VALUE #( FOR ls_order IN lt_orders ( %tky = ls_order-%tky %param = ls_order ) ).
  ENDMETHOD.

  METHOD shipOrder.
    MODIFY ENTITIES OF zi_ecom_orders IN LOCAL MODE ENTITY Orders
      UPDATE FIELDS ( Status ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'SHIPPED' ) ).

    READ ENTITIES OF zi_ecom_orders IN LOCAL MODE ENTITY Orders ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_orders).
    result = VALUE #( FOR ls_order IN lt_orders ( %tky = ls_order-%tky %param = ls_order ) ).
  ENDMETHOD.

ENDCLASS.
