FROM python:latest
#python extensions for flink
RUN 	pip install elasticsearch \
 	&& pip install kafka-python

#jre
# A few problems with compiling Java from source:
#  1. Oracle.  Licensing prevents us from redistributing the official JDK.
#  2. Compiling OpenJDK also requires the JDK to be installed, and it gets
#       really hairy.

RUN apt-get update && apt-get install -y --no-install-recommends \
		bzip2 \
		unzip \
		xz-utils \
	&& rm -rf /var/lib/apt/lists/*

RUN echo 'deb http://deb.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/jessie-backports.list

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jre

ENV JAVA_VERSION 8u111
ENV JAVA_DEBIAN_VERSION 8u111-b14-2~bpo8+1

# see https://bugs.debian.org/775775
# and https://github.com/docker-library/java/issues/19#issuecomment-70546872
ENV CA_CERTIFICATES_JAVA_VERSION 20140324

RUN set -x \
	&& apt-get update \
	&& apt-get install -y \
		openjdk-8-jre-headless="$JAVA_DEBIAN_VERSION" \
		ca-certificates-java="$CA_CERTIFICATES_JAVA_VERSION" \
	&& rm -rf /var/lib/apt/lists/* \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]

# see CA_CERTIFICATES_JAVA_VERSION notes above
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure

#flink
MAINTAINER tobilg@gmail.com

# Set environment variables
ENV FLINK_DATA /data
ENV FLINK_HOME /usr/local/flink
ENV PATH $PATH:$FLINK_HOME/bin

# Install Flink
ENV FLINK_VERSION=1.1.4
ENV HADOOP_VERSION=27
ENV SCALA_VERSION=2.11

RUN curl -s $(curl -s https://www.apache.org/dyn/closer.cgi\?as_json\=1 | awk '/preferred/ {gsub(/"/,""); print $2}')flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala_${SCALA_VERSION}.tgz | tar xvz -C /usr/local/ && \
    ln -s /usr/local/flink-$FLINK_VERSION $FLINK_HOME

# Add container entrypoint
ADD docker-entrypoint.sh docker-entrypoint.sh

# Add base config
ADD flink-conf.yaml $FLINK_HOME/conf/flink-conf.yaml

# Set config env variable
ENV FLINK_CONFIG_FILE $FLINK_HOME/conf/flink-conf.yaml

# Make entrypoint executable and create folders
RUN chmod +x docker-entrypoint.sh && \
    mkdir -p $FLINK_DATA/zk && \
    mkdir -p $FLINK_DATA/tasks && \
    mkdir -p $FLINK_DATA/blobs

WORKDIR /

ENTRYPOINT ["/docker-entrypoint.sh"]
