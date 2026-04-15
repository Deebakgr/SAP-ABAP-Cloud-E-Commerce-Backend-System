CLASS lhc_Behavior DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Behavior RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Behavior.

    METHODS calculateScore FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Behavior~calculateScore.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Behavior~setInitialValues.

    METHODS validateEventType FOR VALIDATE ON SAVE
      IMPORTING keys FOR Behavior~validateEventType.

    METHODS validateProductContext FOR VALIDATE ON SAVE
      IMPORTING keys FOR Behavior~validateProductContext.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Behavior RESULT result.

    METHODS setAddToCart FOR MODIFY
      IMPORTING keys FOR ACTION Behavior~setAddToCart RESULT result.

    METHODS setPurchase FOR MODIFY
      IMPORTING keys FOR ACTION Behavior~setPurchase RESULT result.

    METHODS setView FOR MODIFY
      IMPORTING keys FOR ACTION Behavior~setView RESULT result.

ENDCLASS.

CLASS lhc_Behavior IMPLEMENTATION.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 2. Early Numbering (Crash-Proof Version)
  " ---------------------------------------------------------------------
  METHOD earlynumbering_create.
    DATA: lv_max_active TYPE zecom_behavior-event_id,
          lv_max_draft  TYPE zecom_beh_d-eventid,
          lv_max_id     TYPE zecom_behavior-event_id.

    SELECT SINGLE MAX( event_id ) FROM zecom_behavior INTO @lv_max_active.
    SELECT SINGLE MAX( eventid ) FROM zecom_beh_d INTO @lv_max_draft.

    lv_max_id = COND #( WHEN lv_max_active > lv_max_draft THEN lv_max_active ELSE lv_max_draft ).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      lv_max_id += 1.

      APPEND VALUE #( %cid      = <ls_entity>-%cid
                      %is_draft = <ls_entity>-%is_draft
                      EventId   = lv_max_id ) TO mapped-behavior.
    ENDLOOP.
  ENDMETHOD.

 " ---------------------------------------------------------------------
  " 3. Determination: Set Initial Timestamps (Force IST via Math)
  " ---------------------------------------------------------------------
  METHOD setInitialValues.
    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE
      ENTITY Behavior
        FIELDS ( EventDate EventTime EventTs ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_events).

    " 1. Get the absolute global timestamp (UTC)
    GET TIME STAMP FIELD DATA(lv_ts).

    " 2. Forcefully add 5 hours and 30 minutes (19,800 seconds) for IST
    " This guarantees the time is correct even if the BTP server profile is wrong
    DATA(lv_ist_ts) = cl_abap_tstmp=>add( tstmp = lv_ts
                                          secs  = 19800 ).

    " 3. Extract the new local date and time from our adjusted timestamp
    DATA: lv_local_date TYPE d,
          lv_local_time TYPE t.

    CONVERT TIME STAMP lv_ist_ts TIME ZONE 'UTC'
            INTO DATE lv_local_date TIME lv_local_time.

    " 4. Save the corrected time to the database
    MODIFY ENTITIES OF zi_ecom_behavior IN LOCAL MODE
      ENTITY Behavior
        UPDATE FIELDS ( EventDate EventTime EventTs )
        WITH VALUE #( FOR ls_event IN lt_events
                      ( %tky      = ls_event-%tky
                        EventDate = COND #( WHEN ls_event-EventDate IS INITIAL THEN lv_local_date ELSE ls_event-EventDate )
                        EventTime = COND #( WHEN ls_event-EventTime IS INITIAL THEN lv_local_time ELSE ls_event-EventTime )
                        EventTs   = COND #( WHEN ls_event-EventTs IS INITIAL THEN lv_ts ELSE ls_event-EventTs ) ) )
      REPORTED DATA(lt_update_reported).

    reported = CORRESPONDING #( DEEP lt_update_reported ).
  ENDMETHOD.

  METHOD calculateScore.
    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE
      ENTITY Behavior
        FIELDS ( EventType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_events).

    LOOP AT lt_events ASSIGNING FIELD-SYMBOL(<ls_event>).
      DATA(lv_score) = CONV zecom_behavior-event_score(
        SWITCH #( <ls_event>-EventType
                  WHEN 'VIEW'        THEN '1.00'
                  WHEN 'CLICK'       THEN '2.00'
                  WHEN 'SEARCH'      THEN '3.00'
                  WHEN 'ADD_TO_CART' THEN '5.00'
                  WHEN 'PURCHASE'    THEN '10.00'
                  ELSE '0.00' ) ).

      MODIFY ENTITIES OF zi_ecom_behavior IN LOCAL MODE
        ENTITY Behavior
          UPDATE FIELDS ( EventScore )
          WITH VALUE #( ( %tky = <ls_event>-%tky EventScore = lv_score ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD validateEventType.
    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE
      ENTITY Behavior
        FIELDS ( EventType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_events).

    LOOP AT lt_events INTO DATA(ls_event).
      IF ls_event-EventType <> 'VIEW' AND
         ls_event-EventType <> 'CLICK' AND
         ls_event-EventType <> 'SEARCH' AND
         ls_event-EventType <> 'ADD_TO_CART' AND
         ls_event-EventType <> 'PURCHASE'.

        APPEND VALUE #( %tky = ls_event-%tky ) TO failed-behavior.
        APPEND VALUE #( %tky = ls_event-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Invalid Event Type' )
                        %element-eventtype = if_abap_behv=>mk-on ) TO reported-behavior.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateProductContext.
    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE
      ENTITY Behavior
        FIELDS ( EventType ProductId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_events).

    LOOP AT lt_events INTO DATA(ls_event).
      IF ( ls_event-EventType = 'VIEW' OR
           ls_event-EventType = 'ADD_TO_CART' OR
           ls_event-EventType = 'PURCHASE' )
         AND ls_event-ProductId IS INITIAL.

        APPEND VALUE #( %tky = ls_event-%tky ) TO failed-behavior.
        APPEND VALUE #( %tky = ls_event-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Product ID is mandatory for this event' )
                        %element-productid = if_abap_behv=>mk-on ) TO reported-behavior.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " Feature Control: Disable buttons if the event is already that type
  " ---------------------------------------------------------------------
  METHOD get_instance_features.
    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE
      ENTITY Behavior FIELDS ( EventType ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_events).

    result = VALUE #( FOR ls_event IN lt_events (
      %tky = ls_event-%tky
      %action-setView      = COND #( WHEN ls_event-EventType = 'VIEW' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      %action-setAddToCart = COND #( WHEN ls_event-EventType = 'ADD_TO_CART' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      %action-setPurchase  = COND #( WHEN ls_event-EventType = 'PURCHASE' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
    ) ).
  ENDMETHOD.

  METHOD setAddToCart.
    MODIFY ENTITIES OF zi_ecom_behavior IN LOCAL MODE ENTITY Behavior
      UPDATE FIELDS ( EventType ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky EventType = 'ADD_TO_CART' ) ).

    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE ENTITY Behavior ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_events).
    result = VALUE #( FOR ls_event IN lt_events ( %tky = ls_event-%tky %param = ls_event ) ).
  ENDMETHOD.

  METHOD setPurchase.
    MODIFY ENTITIES OF zi_ecom_behavior IN LOCAL MODE ENTITY Behavior
      UPDATE FIELDS ( EventType ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky EventType = 'PURCHASE' ) ).

    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE ENTITY Behavior ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_events).
    result = VALUE #( FOR ls_event IN lt_events ( %tky = ls_event-%tky %param = ls_event ) ).
  ENDMETHOD.
  " ---------------------------------------------------------------------
  " Action Methods: Update the Event Type
  " ---------------------------------------------------------------------
  METHOD setView.
    MODIFY ENTITIES OF zi_ecom_behavior IN LOCAL MODE ENTITY Behavior
      UPDATE FIELDS ( EventType ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky EventType = 'VIEW' ) ).

    READ ENTITIES OF zi_ecom_behavior IN LOCAL MODE ENTITY Behavior ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_events).
    result = VALUE #( FOR ls_event IN lt_events ( %tky = ls_event-%tky %param = ls_event ) ).
  ENDMETHOD.

ENDCLASS.
