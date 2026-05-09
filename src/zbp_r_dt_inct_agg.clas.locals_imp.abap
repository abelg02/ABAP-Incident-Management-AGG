* Implementación local del handler RAP para la entidad Incident.
* Contiene toda la lógica de negocio: autorizaciones, features, determinaciones,
* la acción changeStatus y las tres validaciones de guardado.
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

  " Autorización global: permite crear, actualizar y eliminar a todos los usuarios del sistema.
  " El control más específico (quién puede cambiar estado) se gestiona dentro de changeStatus.
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
  ENDMETHOD.

  " Autorización por instancia: permite update y delete en cada registro concreto.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND CORRESPONDING #( key ) TO result ASSIGNING FIELD-SYMBOL(<result>).
      IF requested_authorizations-%update = if_abap_behv=>mk-on.
        <result>-%update = if_abap_behv=>auth-allowed.
      ENDIF.
      IF requested_authorizations-%delete = if_abap_behv=>mk-on.
        <result>-%delete = if_abap_behv=>auth-allowed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " Control del botón 'Change Status': decide si está habilitado o deshabilitado para cada incidente.
  " Se deshabilita en dos casos:
  "   1. El incidente ya está cerrado (CO, CL o CN): no tiene sentido seguir cambiando el estado.
  "   2. El incidente es nuevo (borrador sin registro activo): aún no se ha guardado.
  METHOD get_instance_features.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( IncUUID Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents)
      FAILED DATA(read_failed).

    " Extraemos las claves de los registros que están en modo borrador
    DATA lt_draft_keys TYPE TABLE OF zdt_inct_agg.
    lt_draft_keys = VALUE #( FOR inc IN incidents
                              WHERE ( %is_draft = if_abap_behv=>mk-on )
                              ( inc_uuid = inc-IncUUID ) ).

    " Consultamos la tabla activa para saber cuáles borradores ya tienen registro persistido.
    " Si el UUID del borrador no existe en la tabla activa, es una creación nueva.
    DATA lt_active TYPE TABLE OF zdt_inct_agg.
    IF lt_draft_keys IS NOT INITIAL.
      SELECT inc_uuid
        FROM zdt_inct_agg
        FOR ALL ENTRIES IN @lt_draft_keys
        WHERE inc_uuid = @lt_draft_keys-inc_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    result = VALUE #( FOR incident IN incidents
      LET is_closed = xsdbool(    incident-Status = 'CO'
                               OR incident-Status = 'CL'
                               OR incident-Status = 'CN' )
          is_new    = xsdbool( incident-%is_draft = if_abap_behv=>mk-on
                               AND NOT line_exists( lt_active[ inc_uuid = incident-IncUUID ] ) )
      IN
      ( %tky                 = incident-%tky
        %action-changeStatus = COND #( WHEN is_closed = abap_true OR is_new = abap_true
                                       THEN if_abap_behv=>fc-o-disabled
                                       ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  " Determinación on modify (create): rellena automáticamente los campos al abrir el formulario.
  " - IncidentID: siguiente número disponible (MAX actual + 1)
  " - Status: 'OP' (Open) como estado inicial
  " - CreationDate y ChangedDate: fecha actual del sistema
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

  " Determinación on save (create): llama a la acción interna setHistory para crear
  " el primer registro en el historial al guardar el incidente por primera vez.
  METHOD setDefaultHistory.
    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        EXECUTE setHistory
        FROM CORRESPONDING #( keys )
      MAPPED DATA(lc_mapped)
      FAILED DATA(lc_failed)
      REPORTED DATA(lc_reported).
  ENDMETHOD.

  " Acción interna: crea el primer registro de historial para cada incidente nuevo.
  " Valores fijos: HisID=1, PreviousStatus vacío, NewStatus=estado actual (OP), Text='First Incident'.
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
                                             Text           = 'First Incident' ) ) ) )
      MAPPED DATA(lc_mapped)
      FAILED DATA(lc_failed)
      REPORTED DATA(lc_reported).
  ENDMETHOD.

  " Acción changeStatus: gestiona el cambio de estado del incidente.
  " Para cada incidente aplica tres validaciones de negocio con CONTINUE si falla alguna,
  " y si todas pasan: actualiza el estado, calcula el siguiente HisID y crea el registro de historial.
  METHOD changeStatus.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( IncUUID Status ResponsibleUser LocalCreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents)
      FAILED DATA(read_failed).

    INSERT LINES OF read_failed-incident INTO TABLE failed-incident.

    " Obtenemos el usuario técnico que está ejecutando la acción
    DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT incidents INTO DATA(incident).
      DATA(key_entry) = VALUE #( keys[ %tky = incident-%tky ] OPTIONAL ).

      " Validación 1 — Autorización: solo el responsable o el creador (administrador) pueden cambiar el estado
      IF lv_current_user <> incident-LocalCreatedBy
        AND ( incident-ResponsibleUser IS INITIAL OR lv_current_user <> incident-ResponsibleUser ).
        APPEND VALUE #( %tky = incident-%tky ) TO failed-incident.
        APPEND VALUE #( %tky        = incident-%tky
                        %state_area = 'VALIDATE_AUTH_CHANGE'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Only the responsible user or administrator can change the status' ) )
          TO reported-incident.
        CONTINUE.
      ENDIF.

      " Validación 2 — Regla de negocio: no se puede pasar de Pending (PE) a Completed (CO) o Closed (CL)
      IF incident-Status = 'PE'
        AND ( key_entry-%param-Status = 'CO' OR key_entry-%param-Status = 'CL' ).
        APPEND VALUE #( %tky = incident-%tky ) TO failed-incident.
        APPEND VALUE #( %tky        = incident-%tky
                        %state_area = 'VALIDATE_STATUS_CHANGE'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Cannot change status from Pending to Completed or Closed' ) )
          TO reported-incident.
        CONTINUE.
      ENDIF.

      " Validación 3 — Para pasar a In Progress (IP) es obligatorio tener un responsable asignado
      IF key_entry-%param-Status = 'IP' AND incident-ResponsibleUser IS INITIAL.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-incident.
        APPEND VALUE #( %tky                      = incident-%tky
                        %state_area               = 'VALIDATE_RESPONSIBLE'
                        %msg                      = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = 'A responsible user must be assigned before setting status to In Progress' )
                        %element-ResponsibleUser  = if_abap_behv=>mk-on )
          TO reported-incident.
        CONTINUE.
      ENDIF.

      " Si pasó todas las validaciones: actualizamos el estado y la fecha de cambio
      MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
        ENTITY Incident
          UPDATE FIELDS ( Status ChangedDate )
          WITH VALUE #( ( %tky        = incident-%tky
                          Status      = key_entry-%param-Status
                          ChangedDate = cl_abap_context_info=>get_system_date( ) ) )
        FAILED DATA(update_failed)
        REPORTED DATA(update_reported).

      " Leemos el historial actual para calcular el siguiente número de registro
      READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
        ENTITY Incident BY \_History
          ALL FIELDS
          WITH VALUE #( ( %tky = incident-%tky ) )
        RESULT DATA(histories)
        FAILED DATA(hist_failed).

      DATA(next_his_id) = lines( histories ) + 1.

      " Creamos el nuevo registro de historial con el estado anterior, el nuevo y la observación del usuario
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

    " Devolvemos el incidente actualizado como resultado de la acción (refresca la pantalla)
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_incidents).

    result = VALUE #( FOR r IN result_incidents
                      ( %tky   = r-%tky
                        %param = CORRESPONDING #( r ) ) ).
  ENDMETHOD.

  " Validación on save (create + update): comprueba que los 5 campos obligatorios estén informados.
  " Para cada campo vacío, marca el campo en rojo en la UI (%element-<campo> = mk-on).
  METHOD validateMandatoryFields.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( Title Description Priority Status CreationDate )
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

      IF incident-Status IS INITIAL.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky             = incident-%tky
                        %state_area      = 'VALIDATE_MANDATORY'
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = 'Status is mandatory' )
                        %element-Status  = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.

      IF incident-CreationDate IS INITIAL.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky                   = incident-%tky
                        %state_area            = 'VALIDATE_MANDATORY'
                        %msg                   = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = 'Creation date is mandatory' )
                        %element-CreationDate  = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " Validación on save (cuando cambian CreationDate o ChangedDate): dos reglas de negocio:
  "   1. La fecha de creación no puede ser futura.
  "   2. La fecha de modificación no puede ser anterior a la de creación.
  METHOD validateDates.
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( CreationDate ChangedDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT incidents INTO DATA(incident).
      IF incident-CreationDate IS NOT INITIAL
        AND incident-CreationDate > lv_today.
        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.
        APPEND VALUE #( %tky                   = incident-%tky
                        %state_area            = 'VALIDATE_DATES'
                        %msg                   = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = 'Creation date cannot be a future date' )
                        %element-CreationDate  = if_abap_behv=>mk-on )
          TO reported-Incident.
      ENDIF.

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

  " Validación on save (delete): solo se pueden eliminar incidentes con estado 'OP' (Open).
  " Cualquier otro estado indica que el incidente ya está en proceso o finalizado.
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
