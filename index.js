const axios = require('axios');
const cheerio = require('cheerio');
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');

const allTowns = [
    'aytos',
    'balchik',
    'blagoevgrad',
    'burgas',
    'byala',
    'varna',
    'velikipreslav',
    'velikotarnovo',
    'velingrad',
    'gornaoryahovitsa',
    'gotzedelchev',
    'dobrich',
    'isperih',
    'kavarna',
    'kaolinovo',
    'karlovo',
    'karnobat',
    'kneja',
    'kotel',
    'krumovgrad',
    'kubrat',
    'kardjali',
    'lovech',
    'madan',
    'montana',
    'nikipol',
    'novazagora',
    'novipazar',
    'pazardzhik',
    'pleven',
    'plovdiv',
    'provadiya',
    'razgrad',
    'ruse',
    'svistov',
    'silistra',
    'sitovo',
    'sliven',
    'smolyan',
    'sofia',
    'starazagora',
    'tvarditza',
    'targoviste',
    'harmanli',
    'haskovo',
    'shumen',
    'yakoruda',
    'yambol'
];

const prayerNamesEnumeration = {
    1: 'down',
    2: 'sunrise',
    3: 'dhuhr',
    4: 'asr',
    5: 'maghrib',
    6: 'isha'
};

const url = 'https://grandmufti.bg/bg/home/vremena-za-namaz.html';

const outputDir = path.join(__dirname, 'output');

async function getPrayerTimesForMonthAndTown(month, town) {
    const form = new FormData();

    form.append('month', month);
    form.append('town', town);

    try {
        const response = await axios.post(url, form, {
            ...form.getHeaders()
        });

        const pageHtmlAsString = response.data;

        const $ = cheerio.load(pageHtmlAsString);
        const prayerTable = $('.table-prayer-times');

        const prayerTableForTheMonth = {};

        $('tr', prayerTable).each((index, row) => {
            let selectedDate;
            let prayersForThatDay = {};

            $('td', row).each((i, cell) => {
                if (i === 0) {
                    selectedDate = $(cell).text().toLowerCase().trim();
                    return;
                }

                const prayerName = prayerNamesEnumeration[i];
                const prayerTime = $(cell).text().toLowerCase().trim();

                prayersForThatDay[prayerName] = prayerTime;
            });

            if (!selectedDate) {
                return;
            }

            prayerTableForTheMonth[selectedDate] = prayersForThatDay;
        });

        console.log(`Successfully fetched data for month ${month} and ${town}`);
        return prayerTableForTheMonth;
    } catch (error) {
        console.log(error);
    }
}

async function getFullYearPrayersTimeForTown(town) {
    const allMonths = {};
    for (let i = 1; i <= 12; i++) {
        const prayerTableForChosenMonth = await getPrayerTimesForMonthAndTown(
            i,
            town
        );

        allMonths[i] = prayerTableForChosenMonth;
    }

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir);
    }

    const outputFile = path.join(outputDir, `${town}-time.json`);

    fs.writeFileSync(outputFile, JSON.stringify(allMonths, null, 4));
    console.log(`Table data has been saved as ${town}.json`);
}

function getFullYearPrayersTimeForAllTowns(allTowns) {
    allTowns.forEach(async (town) => {
        await getFullYearPrayersTimeForTown(town);
    });
}

// getPrayerTimesForMonthAndCity(8, "sofia");
// getFullYearPrayersTimeForTown('sofia');
getFullYearPrayersTimeForAllTowns(allTowns);
