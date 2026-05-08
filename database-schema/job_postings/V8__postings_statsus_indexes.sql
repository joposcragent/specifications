create index postings_evaluation_status_index
    on job_postings.postings (evaluation_status);

create index postings_response_status_index
    on job_postings.postings (response_status);