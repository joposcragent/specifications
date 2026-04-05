FROM flyway/flyway:10.21.0

COPY migrate.sh /flyway/migrate.sh
RUN chmod +x /flyway/migrate.sh && sed -i 's/\r$//' /flyway/migrate.sh

COPY . /flyway/sql/
RUN rm -f /flyway/sql/migrate.sh

ENTRYPOINT ["/bin/sh", "/flyway/migrate.sh"]
