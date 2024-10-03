function refreshHumidity() {
    fetch('http://192.168.20.138:7799/isu/wen/school/idi/api/data')
        .then(response => response.json())
        .then(data => {
            document.getElementById('sensor1').textContent = `當前濕度 sensor1: ${data.humidity11}%`;
            document.getElementById('sensor2').textContent = `當前濕度 sensor2: ${data.humidity22}%`;
            document.getElementById('sensor3').textContent = `當前濕度 sensor3: ${data.humidity33}%`;

            console.log('Humidity data:', data);
            updateSensorColor(document.getElementById('sensor1'), data.humidity11);
            updateSensorColor(document.getElementById('sensor2'), data.humidity22);
            updateSensorColor(document.getElementById('sensor3'), data.humidity33);
        })
        .catch(error => {
            console.error('Error fetching humidity data:', error);
        });
}

function updateSensorColor(sensorElement, humidityValue) {
    let isRed = false;
    let flashingInterval;

    if (humidityValue >= 0 && humidityValue <= 20) {
        clearInterval(flashingInterval);
        sensorElement.style.backgroundColor = 'white';
    } else if (humidityValue >= 21 && humidityValue <= 70) {
        sensorElement.style.backgroundColor = 'yellow';
    } else if (humidityValue >= 71 && humidityValue < 101) {
        let flashCount = 0;

        flashingInterval = setInterval(() => {
            if (isRed) {
                sensorElement.style.backgroundColor = 'red';
            } else {
                sensorElement.style.backgroundColor = 'blue';
            }
            isRed = !isRed;

            flashCount++;

            if (flashCount >= 2) {
                clearInterval(flashingInterval);
                sensorElement.style.backgroundColor = 'red';
            }
        }, 1500);
    }
}

refreshHumidity();
setInterval(refreshHumidity, 1000);
/*http://192.168.20.138:7799/isu/wen/school/idi/api/data */
/*http://140.127.196.233:888/isu/wen/school/idi/api/data */