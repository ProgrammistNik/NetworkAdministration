# ЛР: Loki + Zabbix + Grafana

## Запуск

```bash
cd lab2
docker compose up -d
```

![compose up](docs/screenshots/00-compose-up.jpg)

![compose ps](docs/screenshots/01-compose-ps.png)

| Куда | Адрес | Логин |
|------|--------|--------|
| Nextcloud | http://127.0.0.1:8080 | создать при первом входе |
| Zabbix | http://127.0.0.1:8081 | `Admin` / `zabbix` |
| Grafana | http://127.0.0.1:3000 | `admin` / `admin` |

```bash
docker compose down -v
```

---

## Часть 1. Логирование

Файлы: `docker-compose.yml`, `promtail_config.yml`.

Nextcloud, логи в data, Promtail читает лог:

![Nextcloud setup](docs/screenshots/02-nextcloud-setup.jpg)

![Nextcloud installed](docs/screenshots/03-nextcloud-installed.jpg)

```bash
docker logs promtail --tail 50
```

![promtail logs](docs/screenshots/04-promtail-logs.jpg)

---

## Часть 2. Мониторинг

Import `template.yml` (Data collection, Templates).

![Zabbix import](docs/screenshots/05-zabbix-import.png)

```bash
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value=nextcloud
```

Host `nextcloud` + шаблон `Test ping template`. Latest data `healthy`:

![Latest data healthy](docs/screenshots/06-zabbix-latest-healthy.png)

Триггер (Problems):

```bash
docker exec -u www-data nextcloud php occ maintenance:mode --on
curl -s http://127.0.0.1:8080/status.php
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

![Problems maintenance](docs/screenshots/07-zabbix-problems.png)

---

## Часть 3. Визуализация

```bash
docker exec grafana grafana-cli plugins install alexanderzobnin-zabbix-app
docker restart grafana
```

Enable плагин Zabbix:

![Zabbix plugin](docs/screenshots/08-grafana-zabbix-plugin.jpg)

Datasources: Loki `http://loki:3100`, Zabbix `http://zabbix-front:8080/api_jsonrpc.php` (`Admin` / `zabbix`).

![Loki datasource](docs/screenshots/09-grafana-loki-ds.png)

![Zabbix datasource](docs/screenshots/10-grafana-zabbix-ds.png)

Дашборд: Stat (статус Nextcloud из Zabbix), таблица логов Loki:

![Grafana dashboard](docs/screenshots/11-grafana-dashboard.png)

---

## Ответы на вопросы

Чем SLO отличается от SLA?  
SLO это внутренняя цель по качеству сервиса. SLA это договор с клиентом об уровне сервиса и ответственности при нарушении.

Чем incremental backup отличается от differential?  
Incremental это только изменения с последнего бэкапа. Differential это изменения с последнего полного. Восстановление: полный и цепочка инкрементов, либо полный и один дифференциальный.

Чем monitoring отличается от observability?  
Monitoring это контроль заранее выбранных метрик и алертов. Observability это возможность понять состояние системы по logs, metrics, traces, в том числе при новых неизвестных сбоях.
