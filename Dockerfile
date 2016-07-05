FROM perl:5.22
MAINTAINER Rob Kinyon rob.kinyon@gmail.com

#RUN apt-get update -qq \
#  && apt-get install -y build-essential 

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm Carton

COPY cpanfile* /tmp/
WORKDIR /tmp
RUN carton install

ENV app /app
RUN mkdir -p $app
WORKDIR $app

ENTRYPOINT [ "/bin/bash" ]
