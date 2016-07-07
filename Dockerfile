FROM perl:5.22
MAINTAINER Rob Kinyon rob.kinyon@gmail.com

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm Carton

ENV app /app
RUN mkdir -p $app
WORKDIR $app

COPY "devops/within_carton" "/usr/local/bin/within_carton"

ENTRYPOINT [ "/usr/local/bin/within_carton" ]
CMD [ "prove" ]
