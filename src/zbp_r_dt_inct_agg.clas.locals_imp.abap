CLASS lhc_incident DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING REQUEST requested_authorizations FOR Incident
        RESULT result,
      get_instance_authorizations FOR INSTANCE AUTHORIZATION
        IMPORTING keys REQUEST requested_authorizations FOR Incident
        RESULT result,
      get_instance_features FOR INSTANCE FEATURES
        IMPORTING keys REQUEST requested_features FOR Incident
        RESULT result,
      setDefaultValues FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Incident~setDefaultValues,
      setDefaultHistory FOR DETERMINE ON SAVE
        IMPORTING keys FOR Incident~setDefaultHistory,
      setHistory FOR MODIFY
        IMPORTING keys FOR ACTION Incident~setHistory,
      changeStatus FOR MODIFY
        IMPORTING keys FOR ACTION Incident~changeStatus RESULT result,
      validateMandatoryFields FOR VALIDATE ON SAVE
        IMPORTING keys FOR Incident~validateMandatoryFields,
      validateDates FOR VALIDATE ON SAVE
        IMPORTING keys FOR Incident~validateDates,
      validateDeleteStatus FOR VALIDATE ON SAVE
        IMPORTING keys FOR Incident~validateDeleteStatus.
ENDCLASS.

CLASS lhc_incident IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-changeStatus = if_abap_behv=>mk-on.
      result-%action-changeStatus = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND CORRESPONDING #( key ) TO result ASSIGNING FIELD-SYMBOL(<result>).
      IF requested_authorizations-%update = if_abap_behv=>mk-on.
        <result>-%update = if_abap_behv=>auth-allowed.
      ENDIF.
      IF requested_authorizations-%delete = if_abap_behv=>mk-on.
        <result>-%delete = if_abap_behv=>auth-allowed.
      ENDIF.
      IF requested_authorizations-%action-changeStatus = if_abap_behv=>mk-on.
        <result>-%action-changeStatus = if_abap_behv=>auth-allowed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents)
      FAILED DATA(read_failed).

    result = VALUE #( FOR incident IN incidents
      LET is_closed = xsdbool(    incident-Status = 'CO'
                               OR incident-Status = 'CL'
                               OR incident-Status = 'CN' )
      IN
      ( %tky                 = incident-%tky
        %action-changeStatus = COND #( WHEN is_closed = abap_true
                                       THEN if_abap_behv=>fc-o-disabled
                                       ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD setDefaultValues.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( IncUUID Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    SELECT SINGLE MAX( incident_id ) FROM zdt_inct_agg INTO @DATA(lv_max_id).

    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        UPDATE FIELDS ( IncidentID Status CreationDate ChangedDate )
        WITH VALUE #( FOR incident IN incidents
                      ( %tky         = incident-%tky
                        IncidentID   = lv_max_id + 1
                        Status       = 'OP'
                        CreationDate = cl_abap_context_info=>get_system_date( )
                        ChangedDate  = cl_abap_context_info=>get_system_date( ) ) )
      REPORTED DATA(lt_reported)
      FAILED DATA(lt_failed).
  ENDMETHOD.

  METHOD setDefaultHistory.
    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        EXECUTE setHistory
        FROM CORRESPONDING #( keys )
      MAPPED DATA(lc_mapped)
      FAILED DATA(lc_failed)
      REPORTED DATA(lc_reported).
  ENDMETHOD.

  METHOD setHistory.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( IncUUID Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        CREATE BY \_History
        FIELDS ( HisID PreviousStatus NewStatus Text )
        WITH VALUE #( FOR i = 1 THEN i + 1 WHILE i <= lines( incidents )
                      ( %tky    = incidents[ i ]-%tky
                        %target = VALUE #( ( %cid           = |HIST_INIT_{ i }|
                                             HisID          = 1
                                             PreviousStatus = ''
                                             NewStatus      = incidents[ i ]-Status
                                             Text           = 'Incident created' ) ) ) )
      MAPPED DATA(lc_mapped)
      FAILED DATA(lc_failed)
      REPORTED DATA(lc_reported).
  ENDMETHOD.

  METHOD changeStatus.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( IncUUID Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents)
      FAILED DATA(read_failed).

    INSERT LINES OF read_failed-incident INTO TABLE failed-incident.

    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        UPDATE FIELDS ( Status ChangedDate )
        WITH VALUE #( FOR key IN keys
                      ( %tky        = key-%tky
                        Status      = key-%param-Status
                        ChangedDate = cl_abap_context_info=>get_system_date( ) ) )
      FAILED DATA(update_failed)
      REPORTED DATA(update_reported).

    LOOP AT incidents INTO DATA(incident).
      DATA(key_entry) = VALUE #( keys[ %tky = incident-%tky ] OPTIONAL ).

      READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
        ENTITY Incident BY \_History
          ALL FIELDS
          WITH VALUE #( ( %tky = incident-%tky ) )
        RESULT DATA(histories)
        FAILED DATA(hist_failed).

      DATA(next_his_id) = lines( histories ) + 1.

      MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
        ENTITY Incident
          CREATE BY \_History
          FIELDS ( HisID PreviousStatus NewStatus Text )
          WITH VALUE #( ( %tky    = incident-%tky
                          %target = VALUE #( ( %cid           = |HIST_CS_{ incident-IncUUID }|
                                               HisID          = next_his_id
                                               PreviousStatus = incident-Status
                                               NewStatus      = key_entry-%param-Status
                                               Text           = key_entry-%param-Text ) ) ) )
        MAPPED DATA(mapped_hist)
        FAILED DATA(failed_hist)
        REPORTED DATA(reported_hist).
    ENDLOOP.

    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_incidents).

    result = VALUE #( FOR r IN result_incidents
                      ( %tky   = r-%tky
                        %param = CORRESPONDING #( r ) ) ).
  ENDMETHOD.

  METHOD validateMandatoryFields.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( Title Description Priority )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    LOOP AT incidents INTO DATA(incident).
      IF incident-Title IS INITIAL.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky            = incident-%tky
                        %state_area     = 'VALIDATE_MANDATORY'
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = 'Title is mandatory' )
                        %element-Title  = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.

      IF incident-Description IS INITIAL.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky                 = incident-%tky
                        %state_area          = 'VALIDATE_MANDATORY'
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'Description is mandatory' )
                        %element-Description = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.

      IF incident-Priority IS INITIAL.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky              = incident-%tky
                        %state_area       = 'VALIDATE_MANDATORY'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Priority is mandatory' )
                        %element-Priority = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( CreationDate ChangedDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    LOOP AT incidents INTO DATA(incident).
      IF incident-CreationDate IS NOT INITIAL
        AND incident-ChangedDate IS NOT INITIAL
        AND incident-ChangedDate < incident-CreationDate.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky                 = incident-%tky
                        %state_area          = 'VALIDATE_DATES'
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'Changed date cannot be before creation date' )
                        %element-ChangedDate = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDeleteStatus.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    LOOP AT incidents INTO DATA(incident).
      IF incident-Status <> 'OP'.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky        = incident-%tky
                        %state_area = 'VALIDATE_DELETE'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Only incidents with status Open can be deleted' ) )
          TO reported-Incident.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
