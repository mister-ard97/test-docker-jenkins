# Panduan Lokal – Ubuntu 24.04

Catatan pribadi untuk menjalankan semua bagian tes di laptop sendiri dan mengumpulkan bukti.
**File ini jangan di-push** (perintah copy di langkah 1 memang tidak menyertakannya).

| Yang jalan | Port |
|---|---|
| Aplikasi `devops-app` | 8080 |
| Jenkins | 8081 |

Urutan kerja:

1. Install Docker
2. Siapkan repo git
3. Part I – build image
4. Part II – run, hotfix, rollback
5. Commit bukti Part I & II
6. Part III – Jenkins
7. Kumpulkan bukti Part III
8. Update angka di README
9. Push dan submit

---

## 1. Install Docker

Go 1.27.1 sudah ter-install (`go version`). Yang perlu di-install hanya Docker:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

sudo usermod -aG docker $USER
newgrp docker            # atau logout lalu login lagi
```

Cek:

```bash
docker version
docker run --rm hello-world
```

## 2. Siapkan repo git

Folder ini hasil download zip, bukan repo git. Jenkins mengambil kode dari GitHub, jadi semua kerja dilakukan di clone repo:

```bash
SRC=/home/finskor006/Documents/backup-kerjaan/Devops-technical-test-pt-journey--main
git clone <URL-REPO-ANDA> ~/devops-test
cd ~/devops-test

git mv "docs/screenshots/part1-docker build .png" docs/screenshots/part1-docker-images.png
git rm -q gitattributes
cp "$SRC/README.md" README.md
cp "$SRC/scripts/watch-downtime.sh" scripts/
chmod +x scripts/*.sh

git add -A
git commit -m "docs: perbarui README dan tambah skrip pengukur downtime"
git push
```

Kalau commit menolak karena identitas belum di-set:
`git config --global user.name "Nama"` dan `git config --global user.email "email@contoh.com"`.

**Semua langkah selanjutnya dijalankan dari `~/devops-test`.**

## 3. Part I – Build

```bash
docker build --build-arg VERSION=1.0.0 -t devops-app:1.0.0 .
docker images devops-app
```

Screenshot output `docker images` → simpan menimpa `docs/screenshots/part1-docker-images.png`
(Ubuntu: tombol `PrtSc`, hasilnya ada di `~/Pictures/Screenshots`).

Cek binary statis dan ukurannya (angkanya dipakai di README):

```bash
mkdir -p build
cid=$(docker create devops-app:1.0.0)
docker cp "$cid:/app/myapp" build/myapp-check && docker rm "$cid"
file build/myapp-check      # harus ada tulisan: statically linked
ls -lh build/myapp-check    # ukuran binary
```

## 4. Part II – Run, hotfix, rollback

### 4.1 Jalankan container

```bash
docker run -d --name devops-app -p 8080:8080 --restart unless-stopped devops-app:1.0.0
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' devops-app   # unless-stopped
curl http://localhost:8080/                                         # version=1.0.0
```

### 4.2 Hotfix: swap binary (butuh 2 terminal)

**Terminal 1** – rekam respons selama swap:

```bash
cd ~/devops-test
bash scripts/watch-downtime.sh | tee docs/downtime.log
```

**Terminal 2** – build binary baru dan swap:

```bash
cd ~/devops-test
CGO_ENABLED=0 GOOS=linux go build -trimpath \
  -ldflags "-s -w -X main.version=1.0.1-hotfix" -o build/myapp .
bash scripts/swap-binary.sh devops-app build/myapp 1.0.1-hotfix | tee docs/swap.log
```

Tunggu ±5 detik setelah skrip selesai, lalu tekan `Ctrl+C` di Terminal 1.
Screenshot Terminal 2 → simpan menimpa `docs/screenshots/part2-hot-swap.png`.

Lihat berapa lama downtime-nya:

```bash
grep -m1 -B4 -A1 'version=1.0.1-hotfix' docs/downtime.log
```

Downtime = jam baris `hotfix` pertama − jam baris `1.0.0` terakhir. Catat angkanya untuk README.

### 4.3 Simulasi swap gagal → rollback

```bash
printf 'bukan binary' > build/broken
bash scripts/swap-binary.sh devops-app build/broken 9.9.9-broken 2>&1 | tee docs/rollback.log
curl http://localhost:8080/       # harus tetap version=1.0.1-hotfix
```

Exit code 1 itu normal. Di `docs/rollback.log` harus ada baris
`GAGAL: version=9.9.9-broken tidak sehat, rollback ke binary lama` dan `Rollback OK: Hello, DevOps! version=1.0.1-hotfix`.

## 5. Commit bukti Part I & II

Commit sekarang supaya working tree bersih sebelum demo test gagal di Part III:

```bash
git add -A
git commit -m "docs: bukti build, hotfix, dan rollback"
git push
```

## 6. Part III – Jenkins

### 6.1 Jalankan Jenkins

```bash
docker build -t jenkins-docker ./jenkins
docker run -d --name jenkins --restart unless-stopped \
  -p 8081:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --add-host=host.docker.internal:host-gateway \
  jenkins-docker

docker logs -f jenkins     # tunggu "Jenkins is fully up and running", lalu Ctrl+C
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 6.2 Setup awal

1. Buka http://localhost:8081, tempel password dari perintah terakhir.
2. Pilih **Install suggested plugins**.
3. Buat user admin, URL Jenkins biarkan default.

### 6.3 Credential

**Token Docker Hub:** hub.docker.com → Account settings → Personal access tokens → Generate new token, permission **Read & Write**. Simpan tokennya.

Di Jenkins: *Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials*

| Field | Isi |
|---|---|
| Kind | Username with password |
| Username | username Docker Hub |
| Password | token Docker Hub |
| ID | `dockerhub-creds` (harus persis) |

Kalau repo GitHub **private**, tambahkan juga credential kedua: Username with password, isi username GitHub + Personal Access Token, ID bebas (misalnya `github-creds`).

### 6.4 Buat job

*New Item* → nama `devops-app-pipeline` → pilih **Pipeline** → OK. Di bagian **Pipeline**:

| Field | Isi |
|---|---|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | URL repo Anda |
| Credentials | `github-creds` (hanya kalau repo private) |
| Branch Specifier | `*/main` |
| Script Path | `jenkins/Jenkinsfile` |

Save.

### 6.5 Run pertama

Build pertama tombolnya masih **Build Now**, karena Jenkins belum membaca parameter `PUSH_IMAGE` dari Jenkinsfile (default: push ke Docker Hub). Setelah build pertama, tombolnya berubah jadi **Build with Parameters**.
Kalau tidak memakai Docker Hub, build pertama akan gagal di stage Push. Jalankan lagi lewat **Build with Parameters** tanpa centang `PUSH_IMAGE`.

Cek hasilnya:

```bash
curl http://localhost:8080/       # version=1.0.1-<hash>
git rev-parse --short HEAD        # <hash> harus sama
```

Container `devops-app` dari Part II sudah ada, jadi stage Deploy akan men-swap binary (bukan `docker run` baru). Itu memang yang mau ditunjukkan.

### 6.6 Demo: pipeline berhenti kalau test gagal

```bash
sed -i 's/want := "Hello, DevOps!/want := "Hello, SALAH!/' main_test.go
go test ./...                     # pastikan FAIL di lokal
git commit main_test.go -m "test: intentional unit test failure for pipeline evidence"
git push
```

Jenkins → **Build with Parameters** → stage **Test merah**, stage berikutnya di-skip.
`curl http://localhost:8080/` harus tetap versi sebelumnya (container tidak disentuh).

Kembalikan test-nya:

```bash
git revert --no-edit HEAD
git push
```

Jenkins → **Build with Parameters** lagi → semua stage hijau.

## 7. Kumpulkan bukti Part III

Ambil console log (buka di browser lalu `Ctrl+S`, atau lewat curl).
API token: klik nama user di kanan atas Jenkins → **Security** → **API Token** → Add new token.

```bash
JENKINS=http://localhost:8081/job/devops-app-pipeline
curl -s -u <USER_JENKINS>:<API_TOKEN> $JENKINS/lastSuccessfulBuild/consoleText > docs/pipeline-success.log
curl -s -u <USER_JENKINS>:<API_TOKEN> $JENKINS/lastFailedBuild/consoleText     > docs/pipeline-test-failed.log

# pastikan isinya benar
grep -E -- '--- FAIL|skipped due to earlier failure' docs/pipeline-test-failed.log
grep -inE 'password|token' docs/*.log      # tidak boleh ada secret yang terlihat
```

Screenshot:

| Simpan sebagai | Isi |
|---|---|
| `docs/screenshots/pipeline-stages-success.png` | build sukses terakhir → menu **Stages** / Pipeline Overview, semua hijau |
| `docs/screenshots/pipeline-test-failed.png` | build test gagal → menu **Stages**, Test merah dan stage lain di-skip |
| `docs/screenshots/pipeline-success.png` | halaman job (daftar build) |
| `docs/screenshots/part3-curl-success.png` | terminal: `curl http://localhost:8080/` + `git log --oneline -3` |

## 8. Update angka di README

README sekarang masih berisi angka dari run lama di Windows. Ganti dengan hasil run Anda:

| Bagian README | Ganti dengan | Ambil dari |
|---|---|---|
| Environment | `Ubuntu 24.04`, `Docker Engine <versi>`, versi Jenkins | `docker version --format '{{.Server.Version}}'` dan `curl -sI http://localhost:8081/login \| grep -i x-jenkins` |
| Quick start | URL clone repo Anda | |
| Part I – blok `docker images` | output baru | `docker images devops-app` |
| Part I – penjelasan ukuran | ukuran binary baru | `ls -lh build/myapp-check` |
| Part II – blok `swap.log` | isi baru | `cat docs/swap.log` |
| Part II – potongan `downtime.log`, "±3 detik", "14 detik" | potongan dan angka baru | perintah `grep` di langkah 4.2 |
| Part II – "Screenshot run lain (1.0.1-04c1687 → ...)" | jadi "Screenshot: ..." | |
| Part III – `1.0.1-90175ba` | hash commit revert | `git rev-parse --short HEAD` |
| Part III – "(build #10)" | nomor build test gagal | halaman job Jenkins |

Penjelasan `CONTENT SIZE` / `DISK USAGE` di README khusus untuk Docker Desktop. Kalau di Ubuntu output `docker images` hanya punya kolom `SIZE`, ganti dua bullet itu dengan:
"`SIZE` ≈ ukuran binary, karena image hanya berisi satu file."

Kalimat "Docker Desktop (backend WSL2) di Windows, shell Git Bash" di Environment juga dihapus.

## 9. Push dan submit

```bash
ls docs/pipeline-success.log docs/pipeline-test-failed.log docs/rollback.log \
   docs/screenshots/pipeline-stages-success.png      # semua harus ada
git add -A
git status                                           # cek tidak ada file aneh
git commit -m "docs: bukti pipeline Jenkins dan update README"
git push
```

Lalu:

1. GitHub repo → **Settings → Collaborators → Add people** → `admin@simplejourney.co.id`
2. Kirim link repo setelah invite terkirim.

---

## Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| `permission denied ... docker.sock` saat menjalankan `docker` di terminal | user belum aktif di grup `docker` | `newgrp docker` atau logout-login |
| `bind: address already in use` | port 8080/8081 dipakai | `sudo ss -ltnp \| grep -E ':808[01]'` |
| Console Jenkins: `docker: not found` | container Jenkins bukan dari `jenkins/Dockerfile` | ulangi langkah 6.1 |
| Console Jenkins: `Cannot connect to the Docker daemon` | socket tidak di-mount | hapus container `jenkins`, jalankan ulang perintah 6.1 (data aman di volume `jenkins_home`) |
| Stage Deploy: `GAGAL ... tidak sehat` padahal `curl localhost:8080` dari host normal | Jenkins tidak bisa menghubungi `host.docker.internal` | cek `docker exec jenkins curl -s http://host.docker.internal:8080/`; kalau gagal, jalankan ulang container Jenkins dengan `--add-host` |
| Stage Push: `unauthorized` | credential salah / token tanpa izin write | cek ID `dockerhub-creds` dan permission token |
| Tidak punya akun Docker Hub | | **Build with Parameters** → hilangkan centang `PUSH_IMAGE` (build pertama akan gagal di Push, itu wajar) |
| Checkout: `Authentication failed` | repo private | tambahkan `github-creds` di konfigurasi job |

## Bersih-bersih (setelah selesai)

```bash
docker rm -f devops-app jenkins
docker image rm devops-app:1.0.0 jenkins-docker
docker volume rm jenkins_home      # HATI-HATI: menghapus semua data Jenkins (job, credential, riwayat build)
```
