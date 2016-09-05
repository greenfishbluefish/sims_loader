FROM perl:5.20
MAINTAINER Rob Kinyon rob.kinyon@gmail.com

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm Carton

ENV app /app
RUN mkdir -p $app
WORKDIR $app

COPY "devops/within_carton" "/usr/local/bin/within_carton"
COPY "devops/MyConfig.pm" "/root/.cpan/CPAN/MyConfig.pm"

ENTRYPOINT [ "/usr/local/bin/within_carton" ]
CMD [ "prove" ]
