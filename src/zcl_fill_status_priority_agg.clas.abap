CLASS zcl_fill_status_priority_agg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_fill_status_priority_agg IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Clear existing data
    DELETE FROM zdt_status_agg.
    DELETE FROM zdt_priority_agg.

    " Insert Status values
    INSERT zdt_status_agg FROM TABLE @( VALUE #(
      ( status_code = 'OP'  status_description = 'Open' )
      ( status_code = 'IP'  status_description = 'In Progress' )
      ( status_code = 'PE'  status_description = 'Pending' )
      ( status_code = 'CO'  status_description = 'Completed' )
      ( status_code = 'CL'  status_description = 'Closed' )
      ( status_code = 'CN'  status_description = 'Canceled' )
    ) ).
    IF sy-subrc = 0.
      out->write( |{ sy-dbcnt } Status records were added successfully| ).
    ENDIF.

    " Insert Priority values
    INSERT zdt_priority_agg FROM TABLE @( VALUE #(
      ( priority_code = 'H'  priority_description = 'High' )
      ( priority_code = 'M'  priority_description = 'Medium' )
      ( priority_code = 'L'  priority_description = 'Low' )
    ) ).
    IF sy-subrc = 0.
      out->write( |{ sy-dbcnt } Priority records were added successfully| ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
