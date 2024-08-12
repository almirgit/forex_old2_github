alter table proxy_list
    add last_availability_check_status boolean  default false;

alter table proxy_list_archive
    add last_availability_check_status boolean;
