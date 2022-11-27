FROM gcr.io/kaniko-project/executor:v1.6.0 as kaniko
FROM jenkins/inbound-agent

USER root

RUN apt update && apt install -y \
	python \
	curl \
	amazon-ecr-credential-helper \
	build-essential \
	libasound2 \
	libbz2-dev \
	libffi-dev \
	libgbm-dev \
	libgconf-2-4 \
	libgtk-3-0 \
	libgtk2.0-0 \
	libncurses-dev \
	libnotify-dev \
	libnss3 \
	libreadline-dev \
	libsqlite3-dev \
	libssl-dev \
	libxss1 \
	libxtst6 \
	python3 \
	python3-pip \
	unzip \
	xauth \
	xvfb \
	zlib1g-dev

# Install AWS CLI
ENV AWSCLI_ZIP "awscliv2.zip"
ENV JAVA_OPTS -XX:-UsePerfData
ENV JNLP_PROTOCOL_OPTS=-Dorg.jenkinsci.remoting.engine.JnlpProtocol3.disabled=false
ENV TERRAFORM_VERSION 0.12.28
ENV TERRAFORM_URL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
ENV TERRAFORM_CHECKSUM "be99da1439a60942b8d23f63eba1ea05ff42160744116e84f46fc24f1a8011b6"
ENV TERRAGRUNT_VERSION 0.23.12
ENV TERRAGRUNT_URL "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
ENV TERRAGRUNT_CHECKSUM "1d6b0d01627a5465170e746b3d8a54c13295189df1ef8bb4cee5e5264c9fa6e3"

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o ${AWSCLI_ZIP} \
  && unzip ${AWSCLI_ZIP} \
  && ./aws/install \
  && rm ${AWSCLI_ZIP}

# Install Terraform
RUN curl -SL "${TERRAFORM_URL}" --output terraform.zip \
  && echo "${TERRAFORM_CHECKSUM} terraform.zip" | sha256sum -c - \
  && unzip "terraform.zip" -d /usr/local/bin \
  && rm terraform.zip

# Install Terragrunt
RUN curl -sL "${TERRAGRUNT_URL}" -o /bin/terragrunt \
  && echo "${TERRAGRUNT_CHECKSUM} /bin/terragrunt" | sha256sum -c - \
  && chmod +x /bin/terragrunt

COPY --from=kaniko /kaniko /kaniko-tools
ENV DOCKER_CONFIG=/kaniko-tools/.docker
ENV PATH=$PATH:/kaniko-tools

RUN pip3 install virtualenv
ENV PATH=$PATH:/home/jenkins/.local/bin

# Install EB CLI
RUN git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git \
  && python ./aws-elastic-beanstalk-cli-setup/scripts/ebcli_installer.py --python-installation /usr/bin/python3 \
  && rm -r aws-elastic-beanstalk-cli-setup
ENV PATH=$PATH:/home/jenkins/.ebcli-virtual-env/executables

# Install Volta (to manage Node versions)
ENV VOLTA_HOME=/home/jenkins/.volta
RUN curl https://get.volta.sh | bash
ENV PATH=$PATH:$VOLTA_HOME/bin

# Set Up SonarQube
ARG sonarRepository=https://binaries.sonarsource.com/Distribution/sonar-scanner-cli
ARG sonarHome=/home/jenkins/.sonar
ARG sonarVersion=4.6.1.2450
ARG sonarInstaller=sonar-scanner-cli-$sonarVersion.zip
ARG sonarBinFolder=$sonarHome/bin
ARG sonarExtractedFolder=$sonarHome/sonar-scanner-$sonarVersion
ENV PATH=$sonarBinFolder:$PATH

RUN rm -rf $sonarHome && \
	mkdir -p $sonarBinFolder && \
	wget -O $sonarHome/$sonarInstaller -q $sonarRepository/$sonarInstaller && \
	unzip $sonarHome/$sonarInstaller -d $sonarHome && \
	mv $sonarExtractedFolder/* $sonarHome && \
	rm -rf $sonarHome/$sonarInstaller $sonarExtractedFolder && \
	chmod +x $sonarBinFolder/*

WORKDIR /opt/java

RUN mkdir -p /usr/lib/jvm

RUN wget https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.16%2B8/OpenJDK11U-jdk_x64_linux_11.0.16_8.tar.gz

RUN tar -xzf OpenJDK11U-jdk_x64_linux_11.0.16_8.tar.gz

RUN ln -s /opt/java/openjdk-11.0.16_8 /usr/lib/jvm/openjdk-11.0.16_8

RUN rm -f OpenJDK11U-jdk_x64_linux_11.0.16_8.tar.gz

WORKDIR /repository

RUN volta install node
