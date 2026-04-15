CLASS lhc_Users DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Users RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Users RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Users.

    METHODS reactivateUser FOR MODIFY
      IMPORTING keys FOR ACTION Users~reactivateUser RESULT result.

    METHODS suspendUser FOR MODIFY
      IMPORTING keys FOR ACTION Users~suspendUser RESULT result.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Users~setInitialValues.

    METHODS setSegment FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Users~setSegment.

    METHODS validateAge FOR VALIDATE ON SAVE
      IMPORTING keys FOR Users~validateAge.

    METHODS validateEmail FOR VALIDATE ON SAVE
      IMPORTING keys FOR Users~validateEmail.

ENDCLASS.

CLASS lhc_Users IMPLEMENTATION.

  " ---------------------------------------------------------------------
  " 1. Instance Features (Dynamically enable/disable UI buttons)
  " ---------------------------------------------------------------------
  METHOD get_instance_features.
    " Read the IsActive flag for the selected users
    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        FIELDS ( IsActive ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users)
      FAILED failed.

    result = VALUE #( FOR ls_user IN lt_users (
      %tky = ls_user-%tky
      " If active, Reactivate is disabled. If inactive, Suspend is disabled.
      %action-reactivateUser = COND #( WHEN ls_user-IsActive = abap_true
                                       THEN if_abap_behv=>fc-o-disabled
                                       ELSE if_abap_behv=>fc-o-enabled )

      %action-suspendUser    = COND #( WHEN ls_user-IsActive = abap_false OR ls_user-IsActive IS INITIAL
                                       THEN if_abap_behv=>fc-o-disabled
                                       ELSE if_abap_behv=>fc-o-enabled )
    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 2. Instance Authorizations (Placeholder)
  " ---------------------------------------------------------------------
  METHOD get_instance_authorizations.
    " Allow all operations by default for this playground scenario.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed
                      %action-reactivateUser = if_abap_behv=>auth-allowed
                      %action-suspendUser    = if_abap_behv=>auth-allowed )
             TO result.
    ENDLOOP.
  ENDMETHOD.
" ---------------------------------------------------------------------
  " Early Numbering (Crash-Proof Draft Version for Users)
  " ---------------------------------------------------------------------
  METHOD earlynumbering_create.
    DATA: lv_max_active TYPE zecom_users-user_id,
          lv_max_draft  TYPE zecom_usr_d-userid,  " No underscore for draft table
          lv_max_id     TYPE zecom_users-user_id.

    " 1. Fetch highest ID from the Active table
    SELECT SINGLE MAX( user_id ) FROM zecom_users INTO @lv_max_active.

    " 2. Fetch highest ID from the Draft table
    SELECT SINGLE MAX( userid ) FROM zecom_usr_d INTO @lv_max_draft.

    " 3. Determine the absolute highest ID between the two
    IF lv_max_active > lv_max_draft.
      lv_max_id = lv_max_active.
    ELSE.
      lv_max_id = lv_max_draft.
    ENDIF.

    " 4. Assign new IDs
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).

      IF <ls_entity>-UserId IS INITIAL.
        " Generate the next available number
        lv_max_id += 1.

        APPEND VALUE #( %cid      = <ls_entity>-%cid
                        %is_draft = <ls_entity>-%is_draft
                        UserId    = lv_max_id ) TO mapped-users.
      ELSE.
        " Pass through safely if provided
        APPEND VALUE #( %cid      = <ls_entity>-%cid
                        %is_draft = <ls_entity>-%is_draft
                        UserId    = <ls_entity>-UserId ) TO mapped-users.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 4. Action: Reactivate User
  " ---------------------------------------------------------------------
  METHOD reactivateUser.
    " Set IsActive to 'X' (True)
    MODIFY ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        UPDATE FIELDS ( IsActive )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky IsActive = abap_true ) )
      FAILED failed
      REPORTED reported.

    " Read and return the updated data to refresh the UI
    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    result = VALUE #( FOR ls_user IN lt_users (
                        %tky   = ls_user-%tky
                        %param = ls_user
                    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 5. Action: Suspend User
  " ---------------------------------------------------------------------
  METHOD suspendUser.
    " Set IsActive to space (False)
    MODIFY ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        UPDATE FIELDS ( IsActive )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky IsActive = abap_false ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    result = VALUE #( FOR ls_user IN lt_users (
                        %tky   = ls_user-%tky
                        %param = ls_user
                    ) ).
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 6. Determination: Set Initial Values
  " ---------------------------------------------------------------------
  METHOD setInitialValues.
    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        FIELDS ( IsActive Segment ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    " Set a user to Active by default when created
    MODIFY ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        UPDATE FIELDS ( IsActive Segment )
        WITH VALUE #( FOR ls_user IN lt_users
                      ( %tky     = ls_user-%tky
                        IsActive = COND #( WHEN ls_user-IsActive IS INITIAL THEN abap_true ELSE ls_user-IsActive )
                        Segment  = COND #( WHEN ls_user-Segment IS INITIAL THEN 'NEW' ELSE ls_user-Segment ) ) )
      REPORTED DATA(lt_update_reported).

    reported = CORRESPONDING #( DEEP lt_update_reported ).
  ENDMETHOD.

 METHOD setSegment.
    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        FIELDS ( Segment ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    LOOP AT lt_users ASSIGNING FIELD-SYMBOL(<ls_user>) WHERE Segment IS INITIAL.
      MODIFY ENTITIES OF zi_ecom_users IN LOCAL MODE
        ENTITY Users
          UPDATE FIELDS ( Segment )
          WITH VALUE #( ( %tky = <ls_user>-%tky Segment = 'STANDARD' ) ). " <-- Changed here!
    ENDLOOP.
  ENDMETHOD.
  " ---------------------------------------------------------------------
  " 8. Validation: Age Check (Must be provided and somewhat valid)
  " ---------------------------------------------------------------------
  METHOD validateAge.
    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        FIELDS ( DateOfBirth ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    DATA(lv_current_date) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_users INTO DATA(ls_user).
      " Check if DOB is initial or in the future
      IF ls_user-DateOfBirth IS INITIAL OR ls_user-DateOfBirth > lv_current_date.
        APPEND VALUE #( %tky = ls_user-%tky ) TO failed-users.

        APPEND VALUE #( %tky = ls_user-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Please enter a valid Date of Birth' )
                        %element-dateofbirth = if_abap_behv=>mk-on ) TO reported-users.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " ---------------------------------------------------------------------
  " 9. Validation: Email Format
  " ---------------------------------------------------------------------
  METHOD validateEmail.
    READ ENTITIES OF zi_ecom_users IN LOCAL MODE
      ENTITY Users
        FIELDS ( Email ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    LOOP AT lt_users INTO DATA(ls_user).
      " Basic check: Must contain an '@' symbol
      IF ls_user-Email IS NOT INITIAL AND ls_user-Email NP '*@*'.
        APPEND VALUE #( %tky = ls_user-%tky ) TO failed-users.

        APPEND VALUE #( %tky = ls_user-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Invalid Email format. Missing @ symbol.' )
                        %element-email = if_abap_behv=>mk-on ) TO reported-users.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
