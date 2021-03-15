FROM python:3.6.13-alpine3.13 AS flask_base

ARG tz="Asia/Taipei"

ENV TZ=${tz} \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8

RUN apk add --no-cache tzdata=~2021 \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && date \
    && apk add --no-cache \
        openssl=~1.1.1 \
    && rm -f /var/cache/apk/*


FROM flask_base AS flask_builder

RUN apk add --no-cache --virtual .builddeps \
      build-base=~0.5 \
      mysql-dev=~10.5 \
    && apk add --no-cache --virtual .devdeps \
      git=~2.30 \
      mysql-client=~10.5 \
    && rm -f /var/cache/apk/*

ARG user="deployer"
ARG flask_env="production"

ENV RELEASE_PATH=/srv/flask \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONFAULTHANDLER=1 \
    # PIPENV_VENV_IN_PROJECT=1 \
    FLASK_ENV=${flask_env}

WORKDIR ${RELEASE_PATH}

RUN if ! id "${user}" >/dev/null 2>&1; then \
      adduser -D ${user}; \
    fi \
    && chown ${user}:${user} ${RELEASE_PATH}

COPY Pipfile Pipfile.lock requirements.txt ./
RUN if [ ${FLASK_ENV} = 'production' ]; then \
      pip install --no-cache-dir -r requirements.txt \
      && pip uninstall pipenv -y \
      && rm -rf ./venv \
      && apk del .builddeps; \
    else \
      pip install --no-cache-dir pipenv==2020.11.15 \
      # && pipenv install --deploy --dev --clear \
      && pipenv install --system --dev --clear \
      && pipenv lock --keep-outdated --requirements > requirements.txt; \
    fi

COPY --chown=${user}:${user} . ${RELEASE_PATH}


# develop stage
FROM flask_builder AS flask_develop

USER root

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint && rm -rf docker

USER ${user}

ENTRYPOINT ["docker-entrypoint"]

EXPOSE 5000

CMD ["python", "app.py"]
