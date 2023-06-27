FROM registry.access.redhat.com/ubi8/ubi

ENV PYTHONUNBUFFERED=0
ENV DJANGO_SETTINGS_MODULE=pulpcore.app.settings
ENV PULP_SETTINGS=/etc/pulp/settings.py
ENV _BUILDAH_STARTED_IN_USERNS=""
ENV BUILDAH_ISOLATION=chroot
ENV PULP_GUNICORN_TIMEOUT=${PULP_GUNICORN_TIMEOUT:-90}
ENV PULP_API_WORKERS=${PULP_API_WORKERS:-2}
ENV PULP_CONTENT_WORKERS=${PULP_CONTENT_WORKERS:-2}

ENV PULP_GUNICORN_RELOAD=${PULP_GUNICORN_RELOAD:-false}
ENV PULP_OTEL_ENABLED=${PULP_OTEL_ENABLED:-false}
ENV PULP_WORKERS=2
ENV PULP_HTTPS=false
ENV PULP_STATIC_ROOT=/var/lib/operator/static/

# Install updates & dnf plugins before disabling python36 to prevent errors
COPY images/repos.d/*.repo /etc/yum.repos.d/
RUN dnf -y install dnf-plugins-core && \
    dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    # dnf config-manager --set-enabled powertools && \
    dnf -y update


# use python38
RUN dnf -y module disable python36
RUN dnf -y module enable python38

# glibc-langpack-en is needed to provide the en_US.UTF-8 locale, which Pulp
# seems to need.
#
RUN dnf -y install python38 python38-cryptography python38-devel && \
    dnf -y --setopt=install_weak_deps=False install openssl openssl-devel && \
    dnf -y --setopt=install_weak_deps=False install openldap-devel && \
    dnf -y --setopt=install_weak_deps=False install wget git && \
    dnf -y --setopt=install_weak_deps=False install python3-psycopg2 && \
    dnf -y --setopt=install_weak_deps=False install python3-createrepo_c && \
    dnf -y --setopt=install_weak_deps=False install redhat-rpm-config gcc cargo libffi-devel && \
    dnf -y --setopt=install_weak_deps=False install glibc-langpack-en && \
    dnf -y --setopt=install_weak_deps=False install libpq-devel && \
    dnf -y --setopt=install_weak_deps=False install python3-setuptools && \
    dnf -y --setopt=install_weak_deps=False install xz && \
    dnf -y --setopt=install_weak_deps=False install libmodulemd-devel && \
    dnf -y --setopt=install_weak_deps=False install libcomps-devel && \
    dnf -y --setopt=install_weak_deps=False install zchunk-devel && \
    dnf -y --setopt=install_weak_deps=False install cmake cairo-gobject-devel && \
    dnf -y --setopt=install_weak_deps=False install libcurl-devel sqlite-devel file-devel && \
    dnf -y --setopt=install_weak_deps=False install zstd

RUN dnf clean all

# Needed to prevent the wrong version of cryptography from being installed,
# which would break PyOpenSSL.
# Need to install optional dep, rhsm, for pulp-certguard
RUN pip3 install --upgrade pip setuptools wheel && \
    rm -rf /root/.cache/pip && \
    pip3 install  \
         rhsm \
         setproctitle \
         gunicorn \
         python-nginx \
         django-storages\[boto3,azure]\>=1.12.2 \
         requests\[use_chardet_on_py3] && \
         rm -rf /root/.cache/pip


RUN pip3 install --upgrade \
  pulpcore \
  pulp-certguard \
  pulp-rpm && \
  rm -rf /root/.cache/pip

# RUN sed 's|^#mount_program|mount_program|g' -i /etc/containers/storage.conf

RUN groupadd -g 700 --system pulp
RUN useradd -d /var/lib/pulp --system -u 700 -g pulp pulp
RUN usermod --add-subuids 100000-165535 --add-subgids 100000-165535 pulp

RUN mkdir -p /etc/pulp/certs \
             /etc/ssl/pulp \
             /var/lib/operator/static \
             /var/lib/pgsql \
             /var/lib/pulp/assets \
             /var/lib/pulp/media \
             /var/lib/pulp/scripts \
             /var/lib/pulp/tmp

RUN chown pulp:pulp -R /var/lib/pulp \
                       /var/lib/operator/static

COPY images/assets/readyz.py /usr/bin/readyz.py
COPY images/assets/route_paths.py /usr/bin/route_paths.py
COPY images/assets/wait_on_postgres.py /usr/bin/wait_on_postgres.py
COPY images/assets/wait_on_database_migrations.sh /usr/bin/wait_on_database_migrations.sh
COPY images/assets/pulp-common-entrypoint.sh /pulp-common-entrypoint.sh
COPY images/assets/pulp-api /usr/bin/pulp-api
COPY images/assets/pulp-content /usr/bin/pulp-content
COPY images/assets/pulp-resource-manager /usr/bin/pulp-resource-manager
COPY images/assets/pulp-worker /usr/bin/pulp-worker

USER pulp:pulp
RUN PULP_STATIC_ROOT=/var/lib/operator/static/ PULP_CONTENT_ORIGIN=localhost \
       /usr/local/bin/pulpcore-manager collectstatic --clear --noinput --link
USER root:root

RUN chmod 2775 /var/lib/pulp/{scripts,media,tmp,assets}
RUN chown :root /var/lib/pulp/{scripts,media,tmp,assets}

CMD ["/init"]
ENTRYPOINT ["/pulp-common-entrypoint.sh"]

EXPOSE 80
