alter table proxy_list
    add last_success_check_date timestamp,
    add last_failure_check_date timestamp;

alter table proxy_list_archive
    add last_success_check_date timestamp,
    add last_failure_check_date timestamp;

