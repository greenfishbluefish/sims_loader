FROM perl:5.22
MAINTAINER Rob Kinyon rob.kinyon@gmail.com

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm Carton

ENV app /app
RUN mkdir -p $app
WORKDIR $app

#ENTRYPOINT [ "/bin/bash" ]
ENTRYPOINT carton install && carton exec prove
