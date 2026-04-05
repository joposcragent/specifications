create type settings.css_query_selector_type as enum (
        'JOB_POSTING_LIST_CARDS',
        'JOB_POSTING_LIST_CARD_TITLE',
        'JOB_POSTING_LIST_CARD_CONTENT_LINK',
        'JOB_POSTING_LIST_PAGES_LINKS',
        'JOB_POSTING_CARD_CONTENT'
    );

alter type settings.css_query_selector_type owner to postgres;

